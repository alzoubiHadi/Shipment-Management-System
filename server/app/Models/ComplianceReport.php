<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ComplianceReport extends Model
{
    const CATEGORIES = ['traffic', 'cargo_damage', 'complaint', 'criminal', 'smuggling', 'forgery', 'other'];

    // Categories that trigger an immediate freeze pending Super Admin
    // review, rather than the normal warning -> suspension escalation.
    const IMMEDIATE_FREEZE_CATEGORIES = ['criminal', 'smuggling', 'forgery'];

    protected $fillable = [
        'driver_id',
        'reported_by_user_id',
        'category',
        'description',
        'evidence_file_path',
        'status',
        'resulting_action',
        'appeal_text',
        'appeal_status',
        'resolved_by_user_id',
        'resolved_at',
    ];

    protected $casts = [
        'resolved_at' => 'datetime',
    ];

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function reportedBy()
    {
        return $this->belongsTo(User::class, 'reported_by_user_id');
    }

    public function resolvedBy()
    {
        return $this->belongsTo(User::class, 'resolved_by_user_id');
    }

    public function isImmediateFreezeCategory(): bool
    {
        return in_array($this->category, self::IMMEDIATE_FREEZE_CATEGORIES, true);
    }
}
