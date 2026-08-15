<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverDestination extends Model
{
    protected $fillable = [
        'driver_id',
        'destination',
    ];

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }
}
