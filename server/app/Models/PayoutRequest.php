<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * UC-30/31/32: driver -> platform withdrawal request. No payment gateway —
 * Finance Admin transfers manually outside the app and attaches a receipt
 * ('paid'); only the driver's own confirmation ('confirmed') actually
 * decrements drivers.balance and lifts the "no new jobs while a payout is
 * pending" lock (Driver::hasPendingPayout()). 'disputed' covers the driver
 * saying they never actually got the money.
 */
class PayoutRequest extends Model
{
    /**
     * Every status a driver is still "mid-payout" for — blocks accepting a
     * new shipment offer until it resolves to 'confirmed' or 'rejected'.
     */
    const BLOCKING_STATUSES = ['pending', 'paid', 'disputed'];

    protected $fillable = [
        'driver_id',
        'amount',
        'status',
        'transfer_receipt_file_path',
        'paid_by_user_id',
        'paid_at',
        'confirmed_at',
        'rejection_reason',
        'dispute_reason',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'paid_at' => 'datetime',
        'confirmed_at' => 'datetime',
    ];

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function paidBy()
    {
        return $this->belongsTo(User::class, 'paid_by_user_id');
    }
}
