<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The financial Ledger — the single source of truth for every balance
     * change on a company or driver account. Balance columns on
     * companies/drivers remain for fast reads, but from this point forward
     * they must ONLY ever be updated by LedgerService::record(), which
     * always writes one of these rows in the same DB transaction.
     *
     * account_type/account_id is a lightweight polymorphic pair (plain
     * strings, mirroring the existing ActivityLog convention rather than
     * Eloquent's morph columns) — account_type is either 'company' or
     * 'driver'. reference_type/reference_id optionally point at the
     * business object that caused this entry (a ShipmentOffer, Shipment,
     * PaymentOrder, PayoutRequest, ...).
     *
     * Rows are append-only: nothing in the app is allowed to update() or
     * delete() a FinancialTransaction after creation (see the model). A
     * mistaken entry is corrected with a new ADJUSTMENT/REVERSAL row, never
     * an edit — this is what makes the balance reconstructable and
     * auditable at any point in time.
     *
     * status/approved_by/approved_at exist so a transaction can be
     * PROPOSED before it actually affects the balance — used by the manual
     * ADJUSTMENT flow (Finance Admin proposes, Super Admin approves) —
     * every other transaction type is inserted already 'posted' since the
     * underlying business action (a Finance Admin approving a deposit, a
     * driver accepting an offer, ...) is itself the approval.
     */
    public function up(): void
    {
        Schema::create('financial_transactions', function (Blueprint $table) {
            $table->id();

            $table->string('account_type'); // 'company' | 'driver'
            $table->unsignedBigInteger('account_id');

            $table->string('transaction_type');
            // Positive = credit (increases balance), negative = debit.
            $table->decimal('amount', 14, 2);
            $table->string('currency', 8)->default('AED');

            $table->decimal('balance_before', 14, 2);
            $table->decimal('balance_after', 14, 2);

            $table->string('reference_type')->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();

            // 'posted' (already applied to balance) | 'pending' (proposed,
            // not yet applied — ADJUSTMENT only) | 'rejected' (proposed,
            // declined, never applied).
            $table->string('status')->default('posted');

            $table->text('description')->nullable();

            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();

            $table->timestamp('created_at')->nullable();

            $table->index(['account_type', 'account_id']);
            $table->index(['reference_type', 'reference_id']);
            $table->index('transaction_type');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('financial_transactions');
    }
};
