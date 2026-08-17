<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Unified Approvals / document-expiry feature (2026-08-22): append-only
 * document history for a truck's three renewable documents, mirroring
 * DriverDocument column-for-column. See DriverDocument::STATUSES for the
 * lifecycle contract (identical here).
 */
class TruckDocument extends Model
{
    const TYPES = ['license', 'insurance', 'technical_inspection'];

    const STATUSES = ['valid', 'expiring_soon', 'expired', 'under_review', 'rejected', 'superseded'];

    protected $fillable = [
        'truck_id',
        'type',
        'file_path',
        'expiry_date',
        'is_current',
        'status',
        'uploaded_by_user_id',
    ];

    protected $casts = [
        'expiry_date' => 'date:Y-m-d',
        'is_current' => 'boolean',
    ];

    public function truck()
    {
        return $this->belongsTo(Truck::class);
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
