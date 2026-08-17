<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Shipment extends Model
{
    use \Illuminate\Database\Eloquent\SoftDeletes;

    protected $fillable = [
        'shipment_offer_id',
        'company_id',
        'driver_id',
        'truck_id',
        'tracking_number',
        'origin',
        'origin_lat',
        'origin_lng',
        'destination',
        'destination_lat',
        'destination_lng',
        'weight',
        'description',
        'needs_permit',
        'is_hazardous',
        'is_fragile',
        'order_type',
        'price_to_driver',
        'price_to_client',
        'status',
        'cancellation_reason',
        'cancelled_by_user_id',
        'cancelled_at',
        'pickup_time',
        'delivered_at',
        'delivery_status',
        'company_confirmed_by_user_id',
        'company_confirmed_at',
        'dispute_reason',
        'current_stage',
        'heading_to_pickup_at',
        'loaded_at',
        'departed_to_border_at',
        'border_cleared_at',
        'arrived_at_destination_at',
        'unloaded_at',
        'pod_signature',
        'pod_recipient_name',
    ];

    protected $casts = [
        'needs_permit' => 'boolean',
        'is_hazardous' => 'boolean',
        'is_fragile' => 'boolean',
        'heading_to_pickup_at' => 'datetime',
        'loaded_at' => 'datetime',
        'departed_to_border_at' => 'datetime',
        'border_cleared_at' => 'datetime',
        'arrived_at_destination_at' => 'datetime',
        'unloaded_at' => 'datetime',
        'delivered_at' => 'datetime',
        'company_confirmed_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'origin_lat' => 'decimal:7',
        'origin_lng' => 'decimal:7',
        'destination_lat' => 'decimal:7',
        'destination_lng' => 'decimal:7',
    ];

    /**
     * Two tracking timelines, keyed by order_type — agreed 2026-08-16.
     * Internal (domestic) shipments never touch a border so they skip
     * those two stages; external (cross-border) shipments keep them. Both
     * lists end the same way with two special stages that are NOT plain
     * driver-tapped timestamps and are handled by dedicated endpoints
     * that already existed before this stage list did:
     *   - "Uploading delivery note" = the proof-of-delivery signature
     *     capture (deliver() below, writes delivered_at).
     *   - "Completed" = the company's own confirmation of receipt
     *     (confirmDelivery() below, writes company_confirmed_at) — the
     *     driver never marks this themselves.
     */
    const STAGE_LABELS = [
        'internal' => [
            1 => 'Going to load',
            2 => 'Loading',
            3 => 'To destination',
            4 => 'Offloading',
            5 => 'Uploading delivery note',
            6 => 'Completed',
        ],
        'external' => [
            1 => 'Going to load',
            2 => 'Loading',
            3 => 'To border',
            4 => 'Crossing the border',
            5 => 'To destination',
            6 => 'Offloading',
            7 => 'Uploading delivery note',
            8 => 'Completed',
        ],
    ];

    /**
     * Stage => timestamp column, for the plain "driver taps to advance"
     * stages only — i.e. every stage EXCEPT the last two special ones
     * above (upload note / completed), which is why this map is shorter
     * than STAGE_LABELS for each order_type.
     */
    const ADVANCE_COLUMNS = [
        'internal' => [
            1 => 'heading_to_pickup_at',
            2 => 'loaded_at',
            3 => 'arrived_at_destination_at',
            4 => 'unloaded_at',
        ],
        'external' => [
            1 => 'heading_to_pickup_at',
            2 => 'loaded_at',
            3 => 'departed_to_border_at',
            4 => 'border_cleared_at',
            5 => 'arrived_at_destination_at',
            6 => 'unloaded_at',
        ],
    ];

    public static function stageLabelsFor(string $orderType): array
    {
        return self::STAGE_LABELS[$orderType] ?? self::STAGE_LABELS['internal'];
    }

    public static function advanceColumnsFor(string $orderType): array
    {
        return self::ADVANCE_COLUMNS[$orderType] ?? self::ADVANCE_COLUMNS['internal'];
    }

    /** Last stage number the driver can reach via advanceStage() — the next stage after this is the delivery-note upload (deliver()). */
    public static function driverAdvanceMaxFor(string $orderType): int
    {
        return count(self::advanceColumnsFor($orderType));
    }

    /** Total stage count for this order_type, including the upload + completed stages. */
    public static function totalStagesFor(string $orderType): int
    {
        return count(self::stageLabelsFor($orderType));
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    public function offer()
    {
        return $this->belongsTo(ShipmentOffer::class, 'shipment_offer_id');
    }

    public function companyConfirmedBy()
    {
        return $this->belongsTo(User::class, 'company_confirmed_by_user_id');
    }

    public function cancelledBy()
    {
        return $this->belongsTo(User::class, 'cancelled_by_user_id');
    }

    /**
     * UC-22: append-only field comments (e.g. a driver flagging a problem
     * mid-shipment). Never edited or deleted once posted.
     */
    public function comments()
    {
        return $this->hasMany(ShipmentComment::class)->orderBy('created_at');
    }

    /**
     * Driver's own delivery action (UC-19): uploads proof + signature, but
     * this alone must NOT free the driver or touch their balance — it only
     * moves the shipment to "awaiting company confirmation".
     */
    public function markAwaitingCompanyConfirmation(): void
    {
        $this->delivery_status = 'awaiting_confirmation';
        $this->save();
    }

    /**
     * The ONLY action that should ever credit the driver's balance for this
     * shipment (UC-20). Caller is responsible for wrapping this together
     * with the driver balance update in a DB transaction.
     */
    public function confirmByCompany(User $companyUser): void
    {
        $this->delivery_status = 'confirmed';
        $this->company_confirmed_by_user_id = $companyUser->id;
        $this->company_confirmed_at = now();
        $this->save();
    }

    public function disputeDelivery(string $reason): void
    {
        $this->delivery_status = 'disputed';
        $this->dispute_reason = $reason;
        $this->save();
    }
}
