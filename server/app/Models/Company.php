<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Company extends Model
{
    //
    use SoftDeletes;
    protected $fillable = [
        'name',
        'email',
        'address',
        'phone',
        'user_id',
        'approval_status',
        'rejection_reason',
        'license_file_path',
        'account_status',
        'suspension_reason',
        'balance',
        'credit_limit',
    ];

    protected $casts = [
        'balance' => 'decimal:2',
        'credit_limit' => 'decimal:2',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function shipments()
    {
        return $this->hasMany(Shipment::class);
    }

    public function shipmentOffers()
    {
        return $this->hasMany(ShipmentOffer::class);
    }

    public function paymentOrders()
    {
        return $this->hasMany(PaymentOrder::class);
    }

    /**
     * Forward-looking credit check for UC-11: creating a new offer must not
     * push (balance - offer price) below -credit_limit. This checks the
     * PROSPECTIVE balance after the new shipment's price, not merely the
     * currently realized balance.
     */
    public function canAffordOffer(float $offerPrice): bool
    {
        return ((float) $this->balance - $offerPrice) >= -((float) $this->credit_limit);
    }

    public function isActive(): bool
    {
        return $this->approval_status === 'approved' && $this->account_status === 'active';
    }
}
