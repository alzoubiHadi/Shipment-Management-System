<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProfileEditRequest extends Model
{
    protected $fillable = [
        'user_id',
        'category',
        'payload',
        'status',
        'admin_note',
        'reviewed_by',
        'reviewed_at',
    ];

    protected $casts = [
        'payload' => 'array',
        'reviewed_at' => 'datetime',
    ];

    // 'truck_document' added for the Unified Approvals / document-expiry
    // feature (2026-08-22) — a driver's truck previously had no renewal
    // workflow at all (see TruckDocument).
    public const CATEGORIES = ['document', 'destinations', 'company_license', 'truck_document'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
