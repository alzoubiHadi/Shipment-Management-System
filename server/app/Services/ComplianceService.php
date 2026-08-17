<?php

namespace App\Services;

use App\Models\Company;
use App\Models\Driver;
use Carbon\Carbon;

/**
 * Compliance/Approval separation feature (2026-08-23): the single source of
 * truth for computing a Driver's or Company's compliance_status — fully
 * independent from approval_status (a driver/company stays 'approved' no
 * matter what this computes; only Driver::suspend()/ComplianceReport
 * resolution touch the misconduct-driven values below, never this service).
 *
 * compliance_status has 4 non-misconduct values, in strict priority order
 * (checked top to bottom — the first that applies wins):
 *   1. active           — every critical document is valid.
 *   2. action_required  — at least one critical document has actually
 *                          expired, OR an admin sent a submitted renewal
 *                          back with "changes required" and the owner
 *                          hasn't resubmitted yet. The account is blocked
 *                          from new matching/shipments until this clears.
 *   3. pending_review    — nothing is currently expired/changes-required,
 *                          but at least one renewal is sitting in the
 *                          admin's queue awaiting a decision.
 *   4. expiring_soon     — nothing above applies, but at least one
 *                          document is within the 30-day warning window.
 *
 * Note this means an expired document with an already-submitted renewal
 * still reads as 'action_required', not 'pending_review' — the account
 * stays blocked (and the owner sees "action required") until an admin
 * actually approves it, not merely because a file was uploaded.
 *
 * compliance_status itself does NOT decide matching/shipment eligibility
 * on its own for the 'expiring_soon' case — see isEligibleForShipment()
 * below, which additionally allows 'expiring_soon' through as long as
 * nothing expires within an order-type-based grace window (3 days
 * internal, 3 months external).
 */
class ComplianceService
{
    const DRIVER_CRITICAL_TYPES = ['license', 'passport', 'residency'];
    const TRUCK_CRITICAL_TYPES = ['license', 'insurance', 'technical_inspection'];
    const COMPANY_CRITICAL_TYPES = ['trade_license'];

    /** Recomputes and persists compliance_status, returning the new value. */
    public static function recalculate(Driver|Company $subject): string
    {
        if ($subject instanceof Driver) {
            // Misconduct states are a completely separate axis (set only by
            // ComplianceReport resolution / DriverController::suspend()) —
            // never overwritten by a document-driven recompute.
            if (! in_array($subject->compliance_status, ['active', 'action_required', 'expiring_soon', 'pending_review'], true)) {
                return $subject->compliance_status;
            }

            $states = self::driverDocumentStates($subject);
        } else {
            $states = self::companyDocumentStates($subject);
        }

        $newStatus = self::highestPriority($states);

        if ($subject->compliance_status !== $newStatus) {
            $subject->update(['compliance_status' => $newStatus]);
        }

        return $newStatus;
    }

    /** @return string[] one effective state ('active'|'action_required'|'pending_review'|'expiring_soon') per critical document type. */
    private static function driverDocumentStates(Driver $driver): array
    {
        $states = [];

        foreach (self::DRIVER_CRITICAL_TYPES as $type) {
            $states[] = self::effectiveState(fn () => $driver->documents(), $type);
        }

        $truck = $driver->truck;
        if ($truck) {
            foreach (self::TRUCK_CRITICAL_TYPES as $type) {
                $states[] = self::effectiveState(fn () => $truck->documents(), $type);
            }
        }

        return $states;
    }

    /** @return string[] */
    private static function companyDocumentStates(Company $company): array
    {
        $states = [];

        foreach (self::COMPANY_CRITICAL_TYPES as $type) {
            $states[] = self::effectiveState(fn () => $company->documents(), $type);
        }

        return $states;
    }

    /**
     * Resolves ONE document type's contribution to the owner's overall
     * compliance, in priority order (first match wins):
     *  1. a not-yet-decided renewal sitting in 'changes_required' (admin
     *     already asked for an edit, owner hasn't resubmitted) always
     *     reads 'action_required' — per spec, the account stays inactive
     *     until resubmission.
     *  2. the still-current row having actually expired reads
     *     'action_required' EVEN IF a renewal is already sitting in
     *     'pending_review' — per spec's account-level order (action_required
     *     before pending_review), the account stays blocked until an admin
     *     actually approves the renewal, not merely because a file was
     *     uploaded.
     *  3. otherwise a renewal genuinely awaiting review ('pending_review')
     *     reads as such.
     *  4. otherwise falls back to the is_current row's own status:
     *     'expiring_soon' as-is; 'valid' (or no dated document on file yet
     *     at all) -> 'active'.
     *
     * [$documentsQuery] is a closure returning a FRESH documents()
     * relation each call — NOT a shared/cloned relation instance. Cloning
     * an Eloquent relation only shallow-copies the wrapper object; its
     * underlying query builder is still the same shared instance, so
     * chained where()s across "clones" would silently accumulate onto one
     * query instead of running independently. Calling ->documents() fresh
     * each time sidesteps that entirely.
     */
    private static function effectiveState(\Closure $documentsQuery, string $type): string
    {
        $hasChangesRequired = $documentsQuery()
            ->where('type', $type)
            ->where('status', 'changes_required')
            ->exists();

        if ($hasChangesRequired) {
            return 'action_required';
        }

        // Expired takes priority over a pending renewal — per spec's
        // account-level order (action_required > pending_review), an
        // expired document that already has a renewal awaiting admin
        // review still blocks the account until the admin actually
        // approves it, not merely because a file was uploaded.
        $current = $documentsQuery()
            ->where('type', $type)
            ->where('is_current', true)
            ->first();

        if ($current && $current->status === 'expired') {
            return 'action_required';
        }

        $hasPendingRenewal = $documentsQuery()
            ->where('type', $type)
            ->where('status', 'pending_review')
            ->exists();

        if ($hasPendingRenewal) {
            return 'pending_review';
        }

        if (! $current) {
            // No dated document on file for this type at all yet — treated
            // as fine rather than blocking, since not every existing
            // account has a row in the new *_documents tables (the
            // legacy license/passport/residency columns predate this
            // table). Missing-document blocking for drivers is already
            // enforced separately by Driver::documentIssues()/
            // isEligibleForNewJob(); this service only concerns itself
            // with documents that DO exist and have a tracked lifecycle.
            return 'active';
        }

        return match ($current->status) {
            'expiring_soon' => 'expiring_soon',
            default => 'active',
        };
    }

    private static function highestPriority(array $states): string
    {
        if (in_array('action_required', $states, true)) {
            return 'action_required';
        }
        if (in_array('pending_review', $states, true)) {
            return 'pending_review';
        }
        if (in_array('expiring_soon', $states, true)) {
            return 'expiring_soon';
        }

        return 'active';
    }

    /**
     * Grace-period follow-up (2026-08-24): 'expiring_soon' alone no longer
     * blocks new matching/shipments outright — the owner stays eligible as
     * long as none of their critical documents expire within an
     * order-type-based grace window before the trip: 3 days for an
     * internal (domestic) shipment, 3 months for an external (cross-border)
     * one, mirroring the existing 3-month cross-border residency rule.
     * 'action_required' (an actually-expired document, or one an admin sent
     * back for changes) and 'pending_review' still hard-block regardless of
     * order type — only 'expiring_soon' gets this extra leniency. 'active'
     * always passes trivially.
     *
     * MatchingService::eligibleDriversQuery() enforces this same rule at
     * the SQL level (for listing/counting eligible drivers) using
     * graceCutoffDate() below to build the exact same cutoff — keep both in
     * sync if this policy ever changes.
     */
    public static function isEligibleForShipment(Driver|Company $subject, string $orderType): bool
    {
        if ($subject->compliance_status === 'active') {
            return true;
        }

        if ($subject->compliance_status !== 'expiring_soon') {
            return false;
        }

        $earliestExpiry = self::earliestCriticalExpiry($subject);

        if ($earliestExpiry === null) {
            return true;
        }

        return $earliestExpiry->gt(self::graceCutoffDate($orderType));
    }

    /** 3 days internal, 3 months external — see isEligibleForShipment(). */
    public static function graceCutoffDate(string $orderType): Carbon
    {
        return $orderType === 'external' ? now()->addMonths(3) : now()->addDays(3);
    }

    /** Soonest expiry date among the subject's current critical documents (and, for a Driver, their truck's), or null if none are on file yet. */
    private static function earliestCriticalExpiry(Driver|Company $subject): ?Carbon
    {
        if ($subject instanceof Driver) {
            $dates = $subject->documents()
                ->whereIn('type', self::DRIVER_CRITICAL_TYPES)
                ->where('is_current', true)
                ->get(['expiry_date'])
                ->pluck('expiry_date');

            $truck = $subject->truck;
            if ($truck) {
                $dates = $dates->merge(
                    $truck->documents()
                        ->whereIn('type', self::TRUCK_CRITICAL_TYPES)
                        ->where('is_current', true)
                        ->get(['expiry_date'])
                        ->pluck('expiry_date')
                );
            }
        } else {
            $dates = $subject->documents()
                ->whereIn('type', self::COMPANY_CRITICAL_TYPES)
                ->where('is_current', true)
                ->get(['expiry_date'])
                ->pluck('expiry_date');
        }

        $dates = $dates->filter()->values();

        return $dates->isEmpty() ? null : $dates->min();
    }
}
