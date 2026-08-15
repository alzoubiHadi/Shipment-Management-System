<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverDocument extends Model
{
    const TYPES = ['license', 'passport', 'residency', 'id_card', 'medical_certificate', 'other'];

    protected $fillable = [
        'driver_id',
        'type',
        'file_path',
        'expiry_date',
        'is_current',
        'uploaded_by_user_id',
    ];

    protected $casts = [
        'expiry_date' => 'date',
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
