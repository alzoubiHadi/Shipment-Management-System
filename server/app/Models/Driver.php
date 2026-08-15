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
        'last_lat',
        'last_lng',
        'last_location_at',
        'offers_received_count',
        'offers_accepted_count',
    ];

    protected $casts = [
        'license_expiry' => 'date',
        'residency_expiry' => 'date',
        'passport_expiry' => 'date',
        'rating' => 'decimal:2',
        'balance' => 'decimal:2',
        'last_lat' => 'decimal:7',
        'last_lng' => 'decimal:7',
        'last_location_at' => 'datetime',
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

    public function complianceReports()
    {
        return $this->hasMany(ComplianceReport::class);
    }

    public function payoutRequests()
    {
        return $this->hasMany(PayoutRequest::class);
    }

    /**
     * A driver is eligible to be offered a new job if they are currently
     * marked available, have been approved by an admin, and none of their
     * required documents have actually expired. A document that was never
     * recorded (null) does NOT block job-matching here — that's a separate,
     * stricter check (see documentIssues()) used specifically to gate
     * *admin approval*, not day-to-day job eligibility, so this keeps the
     * original behaviour for every driver that already passed approval.
     */
    public function isEligibleForNewJob(): bool
    {
        if ($this->status !== 'available') {
            return false;
        }

        if ($this->approval_status !== 'approved') {
            return false;
        }

        // Compliance/safety axis is fully separate from the service rating:
        // a suspended or banned driver never appears in matching regardless
        // of how high their rating is.
        if ($this->compliance_status !== 'active') {
            return false;
        }

        if ($this->license_expiry && $this->license_expiry->isPast()) {
            return false;
        }

        if ($this->passport_expiry && $this->passport_expiry->isPast()) {
            return false;
        }

        if ($this->residency_expiry && $this->residency_expiry->isPast()) {
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
     * List of human-readable problems with this driver's documents — used
     * to decide whether an admin can approve a self-registered driver, and
     * to show warnings in the admin's drivers list. Stricter than
     * isEligibleForNewJob(): a missing license expiry blocks *approval*
     * (the admin must fill it in while reviewing), since self-registration
     * never collects it. Passport/residency are only flagged if expired,
     * not simply missing, since not every driver needs them (e.g. citizens
     * don't need a residency permit).
     */
    public function documentIssues(): array
    {
        $issues = [];

        if (! $this->license_expiry) {
            $issues[] = 'License expiry date missing';
        } elseif ($this->license_expiry->isPast()) {
            $issues[] = 'Driver license expired';
        }

        if ($this->passport_expiry && $this->passport_expiry->isPast()) {
            $issues[] = 'Passport expired';
        }

        if ($this->residency_expiry && $this->residency_expiry->isPast()) {
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
}
