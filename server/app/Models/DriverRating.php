<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverRating extends Model
{
    const SOURCES = ['company', 'super_admin'];

    protected $fillable = [
        'driver_id',
        'shipment_id',
        'rated_by_user_id',
        'source',
        'score',
        'comment',
    ];

    protected $casts = [
        'score' => 'integer',
    ];

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function shipment()
    {
        return $this->belongsTo(Shipment::class);
    }

    public function ratedBy()
    {
        return $this->belongsTo(User::class, 'rated_by_user_id');
    }
}
