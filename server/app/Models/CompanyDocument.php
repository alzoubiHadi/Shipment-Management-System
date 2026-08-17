<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Unified Approvals / document-expiry feature (2026-08-22): append-only
 * document history for a company's renewable documents (only 'trade_license'
 * exists today), mirroring DriverDocument/TruckDocument column-for-column.
 * See DriverDocument::STATUSES for the lifecycle contract (identical here).
 */
class CompanyDocument extends Model
{
    const TYPES = ['trade_license'];

    const STATUSES = ['valid', 'expiring_soon', 'expired', 'pending_review', 'changes_required', 'superseded'];

    protected $fillable = [
        'company_id',
        'type',
        'file_path',
        'expiry_date',
        'is_current',
        'previous_document_id',
        'status',
        'uploaded_by_user_id',
    ];

    protected $casts = [
        'expiry_date' => 'date:Y-m-d',
        'is_current' => 'boolean',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function uploadedBy()
    {
        return $this->belongsTo(User::class, 'uploaded_by_user_id');
    }

    public function previousDocument()
    {
        return $this->belongsTo(self::class, 'previous_document_id');
    }

    public function isExpired(): bool
    {
        return $this->expiry_date !== null && $this->expiry_date->isPast();
    }
}
