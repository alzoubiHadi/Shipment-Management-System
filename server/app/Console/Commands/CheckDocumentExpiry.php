<?php

namespace App\Console\Commands;

use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\Driver;
use App\Models\DocumentExpiryAlert;
use App\Models\DriverDocument;
use App\Models\Truck;
use App\Models\TruckDocument;
use App\Notifications\AppPushNotification;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * Unified Approvals / document-expiry feature (2026-08-22): the daily
 * background check driving the "Valid -> Expiring Soon -> Expired" part of
 * the document lifecycle. For every CURRENT (is_current=true) critical
 * document — a driver's license/passport/residency, a truck's license/
 * insurance/technical inspection, a company's trade license — this:
 *   1. Updates that row's stored `status` column to match today's date
 *      vs its expiry_date ('valid'/'expiring_soon'/'expired').
 *   2. Sends a one-time notification to the owner when the countdown
 *      crosses 30, 15, 7, or 1 day(s) left, or the moment it actually
 *      expires — deduped via DocumentExpiryAlert so the same threshold
 *      never re-fires on a later run.
 *   3. Re-evaluates the owning driver/company's overall compliance_status
 *      (Driver::recomputeComplianceStatus() / Company::
 *      recomputeComplianceStatus()) once per affected owner, so an
 *      in-place expiry — nobody has submitted a renewal yet — still
 *      blocks new-job matching / new-shipment creation automatically,
 *      exactly like an admin-approved renewal already does.
 *
 * Deliberately does NOT create any approval-queue entry here — per spec,
 * "Expiring Soon" (and the daily crossing into "Expired") is notification
 * + alert only; an approval request only ever appears once the driver/
 * company actually submits a renewal (see DriverController::
 * uploadDocument() / TruckController::uploadMyTruckDocument() /
 * ProfileController::submitCompanyLicense()).
 *
 * Registered in bootstrap/app.php's withSchedule() to run daily — same
 * scheduling mechanism as ProcessExpiredMatches (offers:process-expired-matches).
 */
class CheckDocumentExpiry extends Command
{
    protected $signature = 'documents:check-expiry';

    protected $description = 'Update document expiry status, send 30/15/7/1-day notifications, and recompute driver/company compliance';

    /** Smallest-to-largest doesn't matter here — DocumentExpiryAlert::shouldNotify() only cares about the value itself. */
    const THRESHOLDS = [30, 15, 7, 1];

    public function handle(): int
    {
        $touchedDriverIds = [];
        $touchedCompanyIds = [];

        $this->checkDriverDocuments($touchedDriverIds);
        $this->checkTruckDocuments($touchedDriverIds);
        $this->checkCompanyDocuments($touchedCompanyIds);

        foreach (array_unique($touchedDriverIds) as $driverId) {
            Driver::find($driverId)?->recomputeComplianceStatus();
        }
        foreach (array_unique($touchedCompanyIds) as $companyId) {
            Company::find($companyId)?->recomputeComplianceStatus();
        }

        $this->info('Document expiry check complete: ' . count($touchedDriverIds) . ' driver document(s), ' . count($touchedCompanyIds) . ' company document(s) evaluated.');

        return self::SUCCESS;
    }

    private function checkDriverDocuments(array &$touchedDriverIds): void
    {
        $documents = DriverDocument::where('is_current', true)
            ->whereIn('type', ['license', 'passport', 'residency'])
            ->whereNotNull('expiry_date')
            ->with('driver.user')
            ->get();

        foreach ($documents as $document) {
            $driver = $document->driver;
            if (! $driver) {
                continue;
            }

            $result = $this->classify($document->expiry_date);
            if ($document->status !== $result['status']) {
                $document->update(['status' => $result['status']]);
            }

            if ($result['status'] === 'expired' || $result['status'] === 'expiring_soon') {
                $touchedDriverIds[] = $driver->id;
            }

            if (DocumentExpiryAlert::shouldNotify('driver', $driver->id, "{$document->type}_expiry", $result['threshold']) && $driver->user) {
                $driver->user->notify(new AppPushNotification(
                    'document_expiring',
                    $this->titleFor($result['threshold']),
                    sprintf('Your %s %s.', $this->labelFor($document->type), $this->phraseFor($result, $document->expiry_date)),
                    ['document_type' => $document->type, 'expiry_date' => $document->expiry_date->toDateString()],
                ));
            }
        }
    }

    private function checkTruckDocuments(array &$touchedDriverIds): void
    {
        $documents = TruckDocument::where('is_current', true)
            ->whereNotNull('expiry_date')
            ->with('truck.ownerDriver.user')
            ->get();

        foreach ($documents as $document) {
            $truck = $document->truck;
            $driver = $truck?->ownerDriver;
            if (! $driver) {
                continue;
            }

            $result = $this->classify($document->expiry_date);
            if ($document->status !== $result['status']) {
                $document->update(['status' => $result['status']]);
            }

            if ($result['status'] === 'expired' || $result['status'] === 'expiring_soon') {
                $touchedDriverIds[] = $driver->id;
            }

            if (DocumentExpiryAlert::shouldNotify('truck', $truck->id, "{$document->type}_expiry", $result['threshold']) && $driver->user) {
                $driver->user->notify(new AppPushNotification(
                    'document_expiring',
                    $this->titleFor($result['threshold']),
                    sprintf('Your truck\'s %s %s.', $this->truckLabelFor($document->type), $this->phraseFor($result, $document->expiry_date)),
                    ['document_type' => $document->type, 'expiry_date' => $document->expiry_date->toDateString()],
                ));
            }
        }
    }

    private function checkCompanyDocuments(array &$touchedCompanyIds): void
    {
        $documents = CompanyDocument::where('is_current', true)
            ->whereNotNull('expiry_date')
            ->with('company.user')
            ->get();

        foreach ($documents as $document) {
            $company = $document->company;
            if (! $company) {
                continue;
            }

            $result = $this->classify($document->expiry_date);
            if ($document->status !== $result['status']) {
                $document->update(['status' => $result['status']]);
            }

            if ($result['status'] === 'expired' || $result['status'] === 'expiring_soon') {
                $touchedCompanyIds[] = $company->id;
            }

            if (DocumentExpiryAlert::shouldNotify('company', $company->id, "{$document->type}_expiry", $result['threshold']) && $company->user) {
                $company->user->notify(new AppPushNotification(
                    'document_expiring',
                    $this->titleFor($result['threshold']),
                    sprintf('Your %s %s.', $this->labelFor($document->type), $this->phraseFor($result, $document->expiry_date)),
                    ['document_type' => $document->type, 'expiry_date' => $document->expiry_date->toDateString()],
                ));
            }
        }
    }

    /**
     * @return array{status: string, threshold: int|null} threshold is the
     * value to hand to DocumentExpiryAlert::shouldNotify() — one of
     * self::THRESHOLDS, -1 for "just expired", or null for "valid, more
     * than 30 days left" (nothing to notify).
     */
    private function classify(Carbon $expiryDate): array
    {
        $daysUntil = (int) now()->startOfDay()->diffInDays($expiryDate->copy()->startOfDay(), false);

        if ($daysUntil < 0) {
            return ['status' => 'expired', 'threshold' => -1];
        }

        foreach (self::THRESHOLDS as $threshold) {
            if ($daysUntil <= $threshold) {
                return ['status' => 'expiring_soon', 'threshold' => $threshold];
            }
        }

        return ['status' => 'valid', 'threshold' => null];
    }

    private function titleFor(?int $threshold): string
    {
        return $threshold === -1 ? 'Document expired' : 'Document expiring soon';
    }

    private function phraseFor(array $result, Carbon $expiryDate): string
    {
        if ($result['status'] === 'expired') {
            return "expired on {$expiryDate->toDateString()} — you're blocked from new jobs/shipments until it's renewed";
        }

        return "expires in {$result['threshold']} day(s) ({$expiryDate->toDateString()}) — please renew it soon";
    }

    private function labelFor(string $type): string
    {
        return match ($type) {
            'license' => 'driver license',
            'passport' => 'passport',
            'residency' => 'residency permit',
            'trade_license' => 'trade license',
            default => $type,
        };
    }

    /** Truck document types reuse 'license' for the vehicle's own registration — a different label from a driver's own license. */
    private function truckLabelFor(string $type): string
    {
        return match ($type) {
            'license' => 'vehicle registration/license',
            'insurance' => 'insurance',
            'technical_inspection' => 'technical inspection',
            default => $type,
        };
    }
}
