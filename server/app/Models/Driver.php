<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Driver extends Model
{
    //
    use SoftDeletes;
    protected $fillable = [
        'name',
        'phone',
        'truck_number',
        'truck_type',
        'nationality',
        'age',
        'driver_license',
        'license_expiry',
        'user_id',
        'status',
        'approval_status',
        'rejection_reason',
        'admin_note',
        'residency_expiry',
        'passport_expiry',
        'blood_type',
        'health_conditions',
        'rating',
        'compliance_status',
        'balance',
        'bank_name',
        'bank_account_holder',
        'bank_iban',
        'last_lat',
        'last_lng',
        'last_location_at',
        'offers_received_count',
        'offers_accepted_count',
        'last_matched_at',
    ];

    protected $casts = [
        // 'date:Y-m-d' so these serialize as a bare date ("2027-01-01"),
        // not a full ISO datetime — the app was showing a time component
        // alongside every expiry date because of this.
        'license_expiry' => 'date:Y-m-d',
        'residency_expiry' => 'date:Y-m-d',
        'passport_expiry' => 'date:Y-m-d',
        'rating' => 'decimal:2',
        'balance' => 'decimal:2',
        'last_lat' => 'decimal:7',
        'last_lng' => 'decimal:7',
        'last_location_at' => 'datetime',
        'last_matched_at' => 'datetime',
    ];

    /**
     * health_conditions is sensitive medical data: it must NEVER be
     * serialized to a company-facing response. It is intentionally left out
     * of $hidden so admin-facing endpoints can still read/write it directly
     * on the model — company-facing API resources/controllers are
     * responsible for stripping it (see Phase 3 DriverController /
     * DriverResource work).
     */

    // Automatically included in every JSON response for this model, so the
    // app can show document-expiry warnings without any extra API call.
    protected $appends = ['document_issues'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function trucks()
    {
        return $this->hasMany(Truck::class, 'default_driver_id');
    }

    /**
     * Business rule: Driver 1 <-> 1 Truck (enforced at truck-registration
     * time — see TruckController::addMyTruck, which refuses a second
     * truck). This is the "assigned truck" a driver's own accept-offer
     * flow now resolves automatically instead of trusting a client-supplied
     * truck_id — see ShipmentOfferController::accept().
     */
    public function truck()
    {
        return $this->hasOne(Truck::class, 'default_driver_id');
    }

    public function shipments()
    {
        return $this->hasMany(Shipment::class);
    }

    /**
     * Full append-only document history. Never delete a row from here.
     */
    public function documents()
    {
        return $this->hasMany(DriverDocument::class);
    }

    /**
     * Only the currently-valid document per type — this is what
     * document-expiry / auto-block checks should read.
     */
    public function currentDocuments()
    {
        return $this->documents()->where('is_current', true);
    }

    public function destinations()
    {
        return $this->hasMany(DriverDestination::class);
    }

    /**
     * Whether this driver has opted into the given DriverDestination
     * country key (e.g. 'internal_uae', 'saudi_arabia'). See
     * MatchingService::requiredCountriesFor() for how a route's required
     * countries are derived from a shipment offer.
     */
    public function coversCountry(string $countryKey): bool
    {
        return $this->destinations()->where('destination', $countryKey)->exists();
    }

    public function complianceReports()
    {
        return $this->hasMany(ComplianceReport::class);
    }

    public function ratings()
    {
        return $this->hasMany(DriverRating::class);
    }

    public function payoutRequests()
    {
        return $this->hasMany(PayoutRequest::class);
    }

    /**
     * UC-30 special requirement: a driver cannot accept a new shipment
     * offer while a payout request is still mid-flight (pending Finance
     * Admin action, marked paid but not yet driver-confirmed, or
     * disputed). Only 'confirmed' or 'rejected' lifts this.
     */
    public function hasPendingPayout(): bool
    {
        return $this->payoutRequests()
            ->whereIn('status', PayoutRequest::BLOCKING_STATUSES)
            ->exists();
    }

    /**
     * A driver is eligible to be offered a new job if they are currently
     * marked available, approved, in good compliance standing, free of any
     * blocking payout, and every required document is present and valid
     * (see documentIssues() — missing now counts the same as expired). This
     * used to be lenient about a missing (null) expiry date, on the theory
     * that self-registration might not have collected it yet; that's no
     * longer true — UserController::register requires license/passport/
     * residency expiry dates up front for every driver, and
     * DriverController::approve() already refuses to approve a driver with
     * open documentIssues(), so by the time a driver can reach 'approved'
     * these fields are guaranteed to be filled in. Simpler rule, same
     * guarantee: missing/expired critical document = not eligible.
     *
     * [$orderType] ('internal'|'external') is required because compliance
     * eligibility is no longer a flat 'active'-only check (2026-08-24
     * grace-period follow-up): an 'expiring_soon' driver is still eligible
     * unless a critical document expires within the order-type-based grace
     * window — see ComplianceService::isEligibleForShipment().
     */
    public function isEligibleForNewJob(string $orderType): bool
    {
        if ($this->status !== 'available') {
            return false;
        }

        if ($this->approval_status !== 'approved') {
            return false;
        }

        // Compliance/safety axis is fully separate from the service rating:
        // a suspended or banned driver never appears in matching regardless
        // of how high their rating is. 'action_required'/'pending_review'
        // and misconduct states always block here; 'expiring_soon' passes
        // only within the grace window for this order type.
        if (! \App\Services\ComplianceService::isEligibleForShipment($this, $orderType)) {
            return false;
        }

        if ($this->hasPendingPayout()) {
            return false;
        }

        if (! empty($this->documentIssues())) {
            return false;
        }

        return true;
    }

    /**
     * The historical acceptance rate input to the weighted matching score
     * (UC-14). Returns 1.0 (best case) for a brand-new driver with no
     * history yet, so they aren't unfairly penalized before they've had a
     * chance to respond to any offer.
     */
    public function acceptanceRate(): float
    {
        if ($this->offers_received_count <= 0) {
            return 1.0;
        }

        return min(1.0, $this->offers_accepted_count / $this->offers_received_count);
    }

    /**
     * UC-23/UC-24: recomputes `rating` as a recency-weighted average of
     * every DriverRating row (both company-submitted, per-shipment ratings
     * and direct Super Admin ratings) and persists it. Weight decays
     * exponentially with age (90-day half-life) so a driver's rating
     * reflects their recent performance more than something that happened
     * a year ago, without ever fully discarding old history. Falls back to
     * the original 4.5 default (matching the column default) if the driver
     * has no ratings yet, so a brand-new driver is never unfairly zeroed
     * out here.
     */
    public function recalculateRating(): void
    {
        $ratings = $this->ratings()->get(['score', 'created_at']);

        if ($ratings->isEmpty()) {
            $this->update(['rating' => 4.50]);
            return;
        }

        $now = now();
        $weightedSum = 0.0;
        $weightTotal = 0.0;

        foreach ($ratings as $rating) {
            $ageDays = max(0, $rating->created_at->diffInDays($now));
            $weight = 0.5 ** ($ageDays / 90);
            $weightedSum += $rating->score * $weight;
            $weightTotal += $weight;
        }

        $average = $weightTotal > 0 ? $weightedSum / $weightTotal : 4.50;

        $this->update(['rating' => round(min(5, max(1, $average)), 2)]);
    }

    /**
     * List of human-readable problems with this driver's documents — used
     * both to decide whether an admin can approve a self-registered driver
     * (DriverController::approve()) and, since it is now the single source
     * of truth, to gate day-to-day job eligibility (isEligibleForNewJob()).
     *
     * All three documents (license, passport, residency) are mandatory and
     * collected up front at registration (UserController::register), so
     * there is no longer a legitimate "never collected" case to be lenient
     * about — a missing expiry date is treated exactly like an expired one.
     */
    public function documentIssues(): array
    {
        $issues = [];

        if (! $this->license_expiry) {
            $issues[] = 'License expiry date missing';
        } elseif ($this->license_expiry->isPast()) {
            $issues[] = 'Driver license expired';
        }

        if (! $this->passport_expiry) {
            $issues[] = 'Passport expiry date missing';
        } elseif ($this->passport_expiry->isPast()) {
            $issues[] = 'Passport expired';
        }

        if (! $this->residency_expiry) {
            $issues[] = 'Residency expiry date missing';
        } elseif ($this->residency_expiry->isPast()) {
            $issues[] = 'Residency expired';
        }

        return $issues;
    }

    public function getDocumentIssuesAttribute(): array
    {
        return $this->documentIssues();
    }

    /**
     * For international (cross-border) offers the driver's residency must
     * still have at least 3 months left when entering another country.
     */
    public function meetsCrossBorderResidencyRule(): bool
    {
        if (! $this->residency_expiry) {
            return false;
        }

        return $this->residency_expiry->greaterThanOrEqualTo(now()->addMonths(3));
    }

    /**
     * Compliance/Approval separation feature (2026-08-23): thin wrapper
     * kept for every existing call site (CheckDocumentExpiry,
     * ProfileController::applyDocument()/applyTruckDocument(), etc.) —
     * the actual logic now lives in ComplianceService::recalculate(),
     * which resolves compliance_status to one of 'active'/'action_required'/
     * 'pending_review'/'expiring_soon' from the real DriverDocument/
     * TruckDocument rows (not just the denormalized expiry columns this
     * method used to read directly). Still never touches approval_status,
     * and still never overwrites a misconduct state ('warning'/'suspended'/
     * 'banned', set only by ComplianceReport resolution or
     * DriverController::suspend()) — see ComplianceService's docblock.
     */
    public function recomputeComplianceStatus(): void
    {
        \App\Services\ComplianceService::recalculate($this);
    }
}
