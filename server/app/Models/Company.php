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
        'license_expiry',
        'account_status',
        'suspension_reason',
        'compliance_status',
        'balance',
        'credit_limit',
    ];

    protected $casts = [
        'balance' => 'decimal:2',
        'credit_limit' => 'decimal:2',
        'license_expiry' => 'date:Y-m-d',
    ];

    /**
     * Case-insensitivity fix (2026-08-25) — same rule and same reasoning as
     * User::setEmailAttribute(). This is a SEPARATE email column from the
     * linked user's own email (see users.email), used for contact/display
     * purposes, not for login — normalized for consistency with the rest
     * of the app.
     */
    protected function setEmailAttribute(?string $value): void
    {
        $this->attributes['email'] = $value === null ? null : strtolower(trim($value));
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function shipments()
    {
        return $this->hasMany(Shipment::class);
    }

    /**
     * Full append-only trade-license (and any future document type)
     * history — see CompanyDocument::STATUSES.
     */
    public function documents()
    {
        return $this->hasMany(CompanyDocument::class);
    }

    public function currentDocuments()
    {
        return $this->documents()->where('is_current', true);
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
     * Sum of price_to_client across every offer currently holding a
     * reservation against this company (financial_status='reserved') — see
     * the 2026_08_18_000105 migration. Not yet a real SHIPMENT_CHARGE
     * ledger entry, just a hold that keeps a second concurrent offer from
     * spending the same headroom before this one is accepted or cancelled.
     *
     * $excludingOfferId lets a caller re-evaluate ONE specific offer's own
     * price (raisePrice()) without double-counting its own existing hold.
     */
    public function reservedAmount(?int $excludingOfferId = null): float
    {
        $query = ShipmentOffer::where('company_id', $this->id)->where('financial_status', 'reserved');

        if ($excludingOfferId) {
            $query->where('id', '!=', $excludingOfferId);
        }

        return (float) $query->sum('price_to_client');
    }

    /** Balance minus every other offer's active reservation. */
    public function availableBalance(?int $excludingOfferId = null): float
    {
        return (float) $this->balance - $this->reservedAmount($excludingOfferId);
    }

    /**
     * Forward-looking credit check for UC-11: creating (or repricing) an
     * offer must not push (available balance - offer price) below
     * -credit_limit. Uses availableBalance() (balance minus other active
     * reservations), not the raw balance, so two offers created back to
     * back can't both pass this check against the same headroom.
     */
    public function canAffordOffer(float $offerPrice, ?int $excludingOfferId = null): bool
    {
        return ($this->availableBalance($excludingOfferId) - $offerPrice) >= -((float) $this->credit_limit);
    }

    public function isActive(): bool
    {
        return $this->approval_status === 'approved' && $this->account_status === 'active';
    }

    /**
     * Compliance/Approval separation feature (2026-08-23): thin wrapper —
     * see ComplianceService::recalculate() for the actual logic, which now
     * resolves compliance_status to one of 'active'/'action_required'/
     * 'pending_review'/'expiring_soon' from the real CompanyDocument rows
     * (trade_license is the only compliance-relevant company document
     * today). Blocks ShipmentOfferController::create() only —
     * approval_status and account_status are untouched, existing
     * shipments/tracking/finance/documents/profile all stay reachable.
     *
     * Called after every trade-license renewal approval (see
     * ProfileController::applyCompanyLicense()) and by the daily
     * CheckDocumentExpiry command so an in-place expiry (nobody has
     * renewed yet) is caught too, not just a renewal decision.
     */
    public function recomputeComplianceStatus(): void
    {
        \App\Services\ComplianceService::recalculate($this);
    }
}
