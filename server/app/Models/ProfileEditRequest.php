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

    public const CATEGORIES = ['document', 'destinations', 'company_license'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
