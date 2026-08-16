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
