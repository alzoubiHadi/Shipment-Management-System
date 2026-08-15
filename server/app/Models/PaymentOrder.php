<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * UC-28/UC-29: company -> platform top-up request. Company submits an
 * amount + bank-transfer receipt; only Finance Admin approval actually
 * credits companies.balance (never at submission time).
 */
class PaymentOrder extends Model
{
    protected $fillable = [
        'company_id',
        'amount',
        'receipt_file_path',
        'status',
        'reviewed_by_user_id',
        'reviewed_at',
        'rejection_reason',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'reviewed_at' => 'datetime',
    ];

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function reviewedBy()
    {
        return $this->belongsTo(User::class, 'reviewed_by_user_id');
    }
}
