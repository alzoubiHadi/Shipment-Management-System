<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PriceListEntry extends Model
{
    protected $fillable = [
        'destination',
        'truck_type',
        'base_price',
    ];

    protected $casts = [
        'base_price' => 'decimal:2',
    ];
}
