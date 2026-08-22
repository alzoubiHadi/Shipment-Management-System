<?php

namespace App\Console\Commands;

use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\ComplianceReport;
use App\Models\Driver;
use App\Models\DriverDocument;
use App\Models\DriverRating;
use App\Models\FinancialTransaction;
use App\Models\PayoutRequest;
use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\ShipmentOfferDriverResponse;
use App\Models\Truck;
use App\Models\TruckDocument;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * 2026-08-29 (legacy data cleanup, phase 1 — audit only). READ-ONLY: makes
 * no changes to the database or filesystem. Reports exactly what phase 2
 * (a separate, not-yet-written command) would need to fix, so a human can
 * review and approve before anything is touched.
 *
 * Scope, per the cleanup request: Driver/Truck/Company/User rows and their
 * documents ONLY. Never touches Shipment, ShipmentOffer, FinancialTransaction,
 * PriceList, Zone, or any other pricing/historical table — those are only
 * ever READ here (to determine whether a driver/truck/company has real
 * activity attached, which is exactly what makes it unsafe to delete).
 *
 * "Has real activity" = appears as driver_id/company_id/truck_id on a real
 * Shipment, ShipmentOffer, FinancialTransaction, PayoutRequest, DriverRating,
 * ComplianceReport, or ShipmentOfferDriverResponse row. Any row with real
 * activity is NEVER a deletion candidate in this report, only a
 * fix-in-place candidate — deleting it would risk orphaning exactly the
 * historical/pricing data the cleanup must not touch.
 *
 * Business rules this checks against (see the relevant model code):
 *  - Driver::documentIssues(): license_expiry/passport_expiry/residency_expiry
 *    — MISSING counts the same as EXPIRED (no leniency). This is what gates
 *    DriverController::approve() and Driver::isEligibleForNewJob().
 *  - Truck::isRoadworthy(): license_expiry/insurance_expiry/technical_
 *    inspection_expiry — MISSING is fine, only an actually EXPIRED date
 *    blocks. Deliberately more lenient than the driver-side rule.
 *  - One driver, one truck: Truck.default_driver_id, no DB-level unique
 *    constraint (enforced in TruckController::addMyTruck()/create() only).
 *
 * Usage: php artisan data:audit-driver-truck-legacy
 */
class AuditDriverTruckLegacy extends Command
{
    protected $signature = 'data:audit-driver-truck-legacy';

    protected $description = 'Read-only audit of Driver/Truck/Company legacy data ahead of a 1-driver-1-truck cleanup (no changes made)';

    public function handle(): int
    {
        $this->info('=== DRIVER/TRUCK/COMPANY LEGACY DATA AUDIT (read-only) ===');
        $this->newLine();

        $this->section('A. TOP-LEVEL COUNTS');
        $this->countsSection();

        $this->section('B. DRIVER <-> TRUCK RELATIONSHIP (target: 1:1, every driver has exactly one truck)');
        $this->relationshipSection();

        $this->section('C. PER-DRIVER COMPLETENESS + ACTIVITY');
        $this->driverDetailSection();

        $this->section('D. PER-TRUCK COMPLETENESS + ACTIVITY');
        $this->truckDetailSection();

        $this->section('E. PER-COMPANY COMPLETENESS + ACTIVITY');
        $this->companyDetailSection();

        $this->section('F. DOCUMENT FILE EXISTENCE (file_path set in DB vs actually present on disk)');
        $this->fileExistenceSection();

        $this->section('G. approval_status / compliance_status CONSISTENCY');
        $this->consistencySection();

        $this->section('H. SUGGESTED ACTIONS (nothing executed — for your review only)');
        $this->recommendationSection();

        $this->newLine();
        $this->info('=== END OF AUDIT — no data was changed ===');

        return self::SUCCESS;
    }

    private function section(string $title): void
    {
        $this->newLine();
        $this->line("<fg=yellow;options=bold>{$title}</>");
        $this->line(str_repeat('-', strlen($title)));
    }

    // ── A ─────────────────────────────────────────────────────────────────

    private function countsSection(): void
    {
        $this->line('Users (not trashed):   ' . User::count() . '   (trashed: ' . User::onlyTrashed()->count() . ')');
        foreach (['driver', 'company', 'super_admin', 'admin', 'sub_admin'] as $type) {
            $this->line("  - type={$type}: " . User::where('type', $type)->count());
        }
        $this->line('Drivers (not trashed): ' . Driver::count() . '   (trashed: ' . Driver::onlyTrashed()->count() . ')');
        $this->line('Companies (not trashed): ' . Company::count() . '   (trashed: ' . Company::onlyTrashed()->count() . ')');
        $this->line('Trucks (not trashed):  ' . Truck::count() . '   (trashed: ' . Truck::onlyTrashed()->count() . ')');
    }

    // ── B ─────────────────────────────────────────────────────────────────

    private function relationshipSection(): void
    {
        $driversNoTruck = Driver::whereDoesntHave('truck')->get(['id', 'name', 'approval_status']);
        $this->line('Drivers with NO truck: ' . $driversNoTruck->count());
        foreach ($driversNoTruck as $d) {
            $this->line("  - driver #{$d->id}  {$d->name}  approval_status={$d->approval_status}");
        }

        $trucksNoDriver = Truck::whereNull('default_driver_id')->get(['id', 'truck_number']);
        $this->line('Trucks with NO driver (default_driver_id null): ' . $trucksNoDriver->count());
        foreach ($trucksNoDriver as $t) {
            $this->line("  - truck #{$t->id}  {$t->truck_number}");
        }

        // Orphaned: default_driver_id set but points at a driver row that
        // doesn't exist at all, even soft-deleted (would only happen via a
        // manual DB edit, not through app code, but check anyway).
        $orphanTrucks = Truck::whereNotNull('default_driver_id')
            ->whereNotIn('default_driver_id', Driver::withTrashed()->pluck('id'))
            ->get(['id', 'truck_number', 'default_driver_id']);
        $this->line('Trucks whose default_driver_id matches NO driver at all (broken FK): ' . $orphanTrucks->count());
        foreach ($orphanTrucks as $t) {
            $this->line("  - truck #{$t->id}  {$t->truck_number}  default_driver_id={$t->default_driver_id}");
        }

        // Trucks pointing at a SOFT-DELETED driver — the FK still
        // "resolves" but the driver is gone from every normal query.
        $trashedDriverIds = Driver::onlyTrashed()->pluck('id');
        $trucksOnTrashedDriver = Truck::whereIn('default_driver_id', $trashedDriverIds)->get(['id', 'truck_number', 'default_driver_id']);
        $this->line('Trucks pointing at a soft-deleted driver: ' . $trucksOnTrashedDriver->count());
        foreach ($trucksOnTrashedDriver as $t) {
            $this->line("  - truck #{$t->id}  {$t->truck_number}  default_driver_id={$t->default_driver_id} (driver is trashed)");
        }

        // Duplicates: a driver with more than one truck (possible because
        // there's no DB-level unique constraint on default_driver_id — see
        // the 2026-08-29 audit report).
        // Postgres doesn't allow referencing a SELECT-list alias in HAVING
        // (unlike GROUP BY, where it does) — havingRaw() with the real
        // aggregate expression instead of having('truck_count', ...).
        $dupDriverIds = Truck::whereNotNull('default_driver_id')
            ->selectRaw('default_driver_id, COUNT(*) as truck_count')
            ->groupBy('default_driver_id')
            ->havingRaw('COUNT(*) > 1')
            ->pluck('truck_count', 'default_driver_id');
        $this->line('Drivers with MORE THAN ONE truck (violates 1:1): ' . $dupDriverIds->count());
        foreach ($dupDriverIds as $driverId => $count) {
            $driver = Driver::find($driverId);
            $trucks = Truck::where('default_driver_id', $driverId)->get(['id', 'truck_number', 'created_at']);
            $this->line("  - driver #{$driverId} ({$driver?->name}) has {$count} trucks:");
            foreach ($trucks as $t) {
                $this->line("      truck #{$t->id}  {$t->truck_number}  created_at={$t->created_at}");
            }
        }
    }

    // ── C ─────────────────────────────────────────────────────────────────

    private function driverDetailSection(): void
    {
        $driverActivityIds = $this->driverIdsWithActivity();

        foreach (Driver::with('truck')->orderBy('id')->get() as $d) {
            $missingCore = array_filter([
                'phone' => empty($d->phone),
                'driver_license' => empty($d->driver_license),
                'nationality' => empty($d->nationality),
                'age' => empty($d->age),
                'blood_type' => empty($d->blood_type),
            ]);

            $issues = $d->documentIssues(); // license/passport/residency expiry — missing == issue, per the model

            $hasActivity = $driverActivityIds->contains($d->id);

            $this->line(sprintf(
                'driver #%d  %-20s created=%s  approval=%-16s compliance=%-14s truck=%s  activity=%s',
                $d->id,
                $d->name,
                $d->created_at?->toDateString(),
                $d->approval_status,
                $d->compliance_status,
                $d->truck ? '#' . $d->truck->id . ' ' . $d->truck->truck_number : 'NONE',
                $hasActivity ? 'YES (keep, fix only)' : 'no'
            ));
            if ($missingCore) {
                $this->line('    missing core fields: ' . implode(', ', array_keys($missingCore)));
            }
            if ($issues) {
                $this->line('    document issues: ' . implode(' | ', $issues));
            }
        }
    }

    private function driverIdsWithActivity()
    {
        return collect()
            ->merge(Shipment::whereNotNull('driver_id')->pluck('driver_id'))
            ->merge(ShipmentOffer::whereNotNull('accepted_by_driver_id')->pluck('accepted_by_driver_id'))
            ->merge(PayoutRequest::pluck('driver_id'))
            ->merge(DriverRating::pluck('driver_id'))
            ->merge(ComplianceReport::pluck('driver_id'))
            ->merge(ShipmentOfferDriverResponse::pluck('driver_id'))
            ->merge(
                FinancialTransaction::where('reference_type', 'Driver')->pluck('reference_id')
            )
            ->unique()
            ->values();
    }

    // ── D ─────────────────────────────────────────────────────────────────

    private function truckDetailSection(): void
    {
        $truckActivityIds = Shipment::whereNotNull('truck_id')->pluck('truck_id')->unique()->values();

        foreach (Truck::orderBy('id')->get() as $t) {
            $roadworthy = $t->isRoadworthy();
            $hasActivity = $truckActivityIds->contains($t->id)
                || ($t->default_driver_id && $this->driverIdsWithActivity()->contains($t->default_driver_id));

            $this->line(sprintf(
                'truck #%d  %-15s type=%-25s driver_id=%s  active=%s  roadworthy=%s  activity=%s',
                $t->id,
                $t->truck_number,
                $t->truck_type,
                $t->default_driver_id ?? 'NONE',
                $t->is_active ? 'Y' : 'N',
                $roadworthy ? 'Y' : 'N',
                $hasActivity ? 'YES (keep, fix only)' : 'no'
            ));

            $fileNotes = [];
            foreach (['license_file_path', 'insurance_file_path', 'technical_inspection_file_path'] as $col) {
                $path = $t->$col;
                if ($path === null) {
                    $fileNotes[] = "{$col}=NULL";
                } else {
                    $exists = Storage::disk('local')->exists($path) || Storage::disk('public')->exists($path);
                    $fileNotes[] = "{$col}=" . ($exists ? 'OK' : 'MISSING ON DISK');
                }
            }
            $this->line('    ' . implode('  ', $fileNotes));
        }
    }

    // ── E ─────────────────────────────────────────────────────────────────

    private function companyDetailSection(): void
    {
        $companyActivityIds = collect()
            ->merge(Shipment::whereNotNull('company_id')->pluck('company_id'))
            ->merge(ShipmentOffer::whereNotNull('company_id')->pluck('company_id'))
            ->merge(\App\Models\PaymentOrder::pluck('company_id'))
            ->merge(FinancialTransaction::where('reference_type', 'Company')->pluck('reference_id'))
            ->unique()
            ->values();

        foreach (Company::orderBy('id')->get() as $c) {
            $hasActivity = $companyActivityIds->contains($c->id);
            $licenseNote = 'no file';
            if ($c->license_file_path) {
                $exists = Storage::disk('local')->exists($c->license_file_path) || Storage::disk('public')->exists($c->license_file_path);
                $licenseNote = $exists ? 'file OK' : 'file MISSING ON DISK';
            }

            $this->line(sprintf(
                'company #%d  %-20s created=%s  approval=%-16s phone=%s  license=%s  activity=%s',
                $c->id,
                $c->name,
                $c->created_at?->toDateString(),
                $c->approval_status,
                empty($c->phone) ? 'MISSING' : 'ok',
                $licenseNote,
                $hasActivity ? 'YES (keep, fix only)' : 'no'
            ));
        }
    }

    // ── F ─────────────────────────────────────────────────────────────────

    private function fileExistenceSection(): void
    {
        $this->checkDocsTable('DriverDocument', DriverDocument::all(['id', 'driver_id', 'type', 'file_path']));
        $this->checkDocsTable('TruckDocument', TruckDocument::all(['id', 'truck_id', 'type', 'file_path']));
        $this->checkDocsTable('CompanyDocument', CompanyDocument::all(['id', 'company_id', 'type', 'file_path']));
    }

    private function checkDocsTable(string $label, $rows): void
    {
        $missing = 0;
        $ok = 0;
        foreach ($rows as $row) {
            if (! $row->file_path) {
                continue;
            }
            $exists = Storage::disk('local')->exists($row->file_path) || Storage::disk('public')->exists($row->file_path);
            $exists ? $ok++ : $missing++;
        }
        $this->line("{$label}: {$rows->count()} rows total, " . $rows->whereNull('file_path')->count() . ' with no file_path, ' . "{$ok} file(s) present on disk, {$missing} file(s) MISSING on disk");
    }

    // ── G ─────────────────────────────────────────────────────────────────

    private function consistencySection(): void
    {
        $approvedWithIssues = Driver::where('approval_status', 'approved')->get()
            ->filter(fn ($d) => ! empty($d->documentIssues()));
        $this->line("Drivers marked 'approved' but with open document issues (missing/expired required dates): " . $approvedWithIssues->count());
        foreach ($approvedWithIssues as $d) {
            $this->line("  - driver #{$d->id} {$d->name}: " . implode(' | ', $d->documentIssues()));
        }

        $approvedNoTruck = Driver::where('approval_status', 'approved')->whereDoesntHave('truck')->get(['id', 'name']);
        $this->line("Drivers marked 'approved' but with NO truck at all: " . $approvedNoTruck->count());
        foreach ($approvedNoTruck as $d) {
            $this->line("  - driver #{$d->id} {$d->name}");
        }

        $approvedCompanyNoLicense = Company::where('approval_status', 'approved')->whereNull('license_file_path')->get(['id', 'name']);
        $this->line("Companies marked 'approved' but with NO license file at all: " . $approvedCompanyNoLicense->count());
        foreach ($approvedCompanyNoLicense as $c) {
            $this->line("  - company #{$c->id} {$c->name}");
        }
    }

    // ── H ─────────────────────────────────────────────────────────────────

    private function recommendationSection(): void
    {
        $activityIds = $this->driverIdsWithActivity();

        $this->line('Heuristic used: any driver/truck/company with real activity (a Shipment, ShipmentOffer, FinancialTransaction, PayoutRequest, DriverRating, ComplianceReport, or ShipmentOfferDriverResponse referencing it) is NEVER suggested for deletion — only for fixing in place. Everything below is a suggestion for your review; phase 2 will not run until you approve specific IDs.');
        $this->newLine();

        $deleteCandidates = Driver::whereDoesntHave('truck')->get()->filter(fn ($d) => ! $activityIds->contains($d->id));
        $this->line('DELETE candidates — drivers with no truck AND no real activity: ' . $deleteCandidates->count());
        foreach ($deleteCandidates as $d) {
            $this->line("  - driver #{$d->id} {$d->name} (created {$d->created_at?->toDateString()})");
        }

        $orphanTruckDelete = Truck::whereNull('default_driver_id')->get()->filter(function ($t) {
            return ! Shipment::where('truck_id', $t->id)->exists();
        });
        $this->line('DELETE candidates — trucks with no driver AND no shipment history: ' . $orphanTruckDelete->count());
        foreach ($orphanTruckDelete as $t) {
            $this->line("  - truck #{$t->id} {$t->truck_number}");
        }

        $fixInPlace = Driver::get()->filter(fn ($d) => ! empty($d->documentIssues()) && ($activityIds->contains($d->id) || $d->truck));
        $this->line('FIX-IN-PLACE candidates — drivers with document date issues that either have a truck or real activity (never delete these): ' . $fixInPlace->count());
        foreach ($fixInPlace as $d) {
            $this->line("  - driver #{$d->id} {$d->name}: " . implode(' | ', $d->documentIssues()));
        }
    }
}
