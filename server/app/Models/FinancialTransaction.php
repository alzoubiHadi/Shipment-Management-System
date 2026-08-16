<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * The financial Ledger. Append-only — see the migration for why. Every row
 * is written exclusively through LedgerService (never call
 * FinancialTransaction::create() directly from a controller), so that a
 * balance_before/balance_after pair and the account's actual `balance`
 * column always move together, atomically, under a row lock.
 */
class FinancialTransaction extends Model
{
    public $timestamps = false; // only created_at, set explicitly

    /** account_type values. */
    public const ACCOUNT_COMPANY = 'company';
    public const ACCOUNT_DRIVER = 'driver';

    /**
     * transaction_type values. OPENING_BALANCE is an addition on top of the
     * spec's list — needed to seed the ledger with each account's balance
     * at the moment this system went live, without altering that balance.
     */
    public const TYPES = [
        'OPENING_BALANCE',
        'COMPANY_DEPOSIT',
        'SHIPMENT_CHARGE',
        'DRIVER_EARNING',
        'DRIVER_PAYOUT',
        'PAYOUT_REVERSAL',
        'REFUND',
        'ADJUSTMENT',
    ];

    public const STATUS_POSTED = 'posted';
    public const STATUS_PENDING = 'pending';
    public const STATUS_REJECTED = 'rejected';

    protected $fillable = [
        'account_type',
        'account_id',
        'transaction_type',
        'amount',
        'currency',
        'balance_before',
        'balance_after',
        'reference_type',
        'reference_id',
        'status',
        'description',
        'created_by',
        'approved_by',
        'approved_at',
        'created_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'balance_before' => 'decimal:2',
        'balance_after' => 'decimal:2',
        'approved_at' => 'datetime',
        'created_at' => 'datetime',
    ];

    public function createdBy()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approvedBy()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    /**
     * The Company or Driver model this entry belongs to, resolved from the
     * plain account_type/account_id pair.
     */
    public function account()
    {
        return match ($this->account_type) {
            self::ACCOUNT_COMPANY => Company::find($this->account_id),
            self::ACCOUNT_DRIVER => Driver::find($this->account_id),
            default => null,
        };
    }

    /** The business record (ShipmentOffer, Shipment, PaymentOrder, ...) this entry references, if any. */
    public function reference()
    {
        if (! $this->reference_type || ! $this->reference_id) {
            return null;
        }

        $map = [
            'ShipmentOffer' => \App\Models\ShipmentOffer::class,
            'Shipment' => \App\Models\Shipment::class,
            'PaymentOrder' => \App\Models\PaymentOrder::class,
            'PayoutRequest' => \App\Models\PayoutRequest::class,
        ];

        $class = $map[$this->reference_type] ?? null;

        return $class ? $class::find($this->reference_id) : null;
    }
}
