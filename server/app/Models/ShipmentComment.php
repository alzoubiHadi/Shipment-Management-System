<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ShipmentComment extends Model
{
    protected $fillable = [
        'shipment_id',
        'user_id',
        'comment',
    ];

    public function shipment()
    {
        return $this->belongsTo(Shipment::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
