<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverDocument extends Model
{
    // 'license_back' and 'driver_photo' added for the new registration
    // design (2026-08-19): license front is still plain 'license',
    // 'license_back' is its reverse side, 'driver_photo' is a plain
    // portrait photo of the driver (not a document scan).
    const TYPES = ['license', 'license_back', 'passport', 'residency', 'id_card', 'driver_photo', 'medical_certificate', 'other'];

    /**
     * Unified Approvals / document-expiry feature (2026-08-22): a real
     * stored lifecycle per row instead of derived-at-read-time. 'valid' and
     * 'expiring_soon'/'expired' only ever apply to the is_current row for
     * that type; 'under_review'/'rejected' only ever apply to a NOT-current
     * row created by a pending renewal upload; 'superseded' is the
     * terminal state an old row moves to once its replacement is approved.
     * See CheckDocumentExpiry (the daily command) for valid<->expiring_soon
     * <->expired transitions, and ProfileController::applyDocument()/
     * reject() for the under_review->valid/rejected/superseded transitions.
     */
    const STATUSES = ['valid', 'expiring_soon', 'expired', 'under_review', 'rejected', 'superseded'];

    protected $fillable = [
        'driver_id',
        'type',
        'file_path',
        'expiry_date',
        'is_current',
        'status',
        'uploaded_by_user_id',
    ];

    protected $casts = [
        // 'date:Y-m-d' (not plain 'date') so the API/JSON response is a bare
        // date like "2027-01-01" — plain 'date' still serializes Carbon's
        // full ISO datetime, which is why the app was showing a time
        // alongside every expiry date.
        'expiry_date' => 'date:Y-m-d',
        'is_current' => 'boolean',
    ];

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function uploadedBy()
    {
        return $this->belongsTo(User::class, 'uploaded_by_user_id');
    }

    public function isExpired(): bool
    {
        return $this->expiry_date !== null && $this->expiry_date->isPast();
    }
}
