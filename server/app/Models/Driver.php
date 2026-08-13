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
        'employment_type',
        'status',
        'approval_status',
        'rejection_reason',
        'residency_expiry',
        'passport_expiry',
        'blood_type',
    ];

    protected $casts = [
        'license_expiry' => 'date',
        'residency_expiry' => 'date',
        'passport_expiry' => 'date',
    ];

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
