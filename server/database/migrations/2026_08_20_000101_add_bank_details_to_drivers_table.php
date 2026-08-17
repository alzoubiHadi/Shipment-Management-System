<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Driver Phase 5 (2026-08-20): "Bank Details" section on the driver
 * Profile screen — the earnings ledger (FinancialTransaction/payouts)
 * already existed, but there was nowhere to record which account a
 * driver's payout should actually go to. Kept to the three fields an
 * admin/finance team needs to action a bank transfer manually; nothing
 * automated reads these yet.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->string('bank_name')->nullable()->after('balance');
            $table->string('bank_account_holder')->nullable()->after('bank_name');
            $table->string('bank_iban')->nullable()->after('bank_account_holder');
        });
    }

    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropColumn(['bank_name', 'bank_account_holder', 'bank_iban']);
        });
    }
};
