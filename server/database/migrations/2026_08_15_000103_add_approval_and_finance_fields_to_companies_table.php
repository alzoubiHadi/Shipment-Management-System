<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Companies now self-register (see users.otp_code flow) and require
     * Super Admin final approval, exactly like drivers already did
     * (2026_07_07_090000_add_approval_status_to_drivers_table.php).
     *
     * account_status is a SEPARATE concept from approval_status: an already
     * approved company can later be temporarily suspended by an admin for a
     * rules violation, independent of the one-time approval workflow.
     *
     * balance / credit_limit power the forward-looking credit check in
     * UC-11: a new offer is blocked when (balance - offer price) would go
     * below -credit_limit. Default credit_limit is 0 (no credit extended by
     * default) per the client's explicit instruction; Finance Admin raises
     * it per company as needed.
     */
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->enum('approval_status', ['pending', 'approved', 'rejected'])
                ->default('approved')
                ->after('user_id');

            // Used for BOTH outright rejection reasons and "return for
            // completion" messages (status stays 'pending' in the latter
            // case; see Driver's own admin_note field for the same pattern).
            $table->string('rejection_reason')->nullable()->after('approval_status');

            $table->enum('account_status', ['active', 'suspended'])
                ->default('active')
                ->after('rejection_reason');
            $table->string('suspension_reason')->nullable()->after('account_status');

            $table->decimal('balance', 12, 2)->default(0)->after('suspension_reason');
            $table->decimal('credit_limit', 12, 2)->default(0)->after('balance');

            $table->index('approval_status');
            $table->index('account_status');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropIndex(['approval_status']);
            $table->dropIndex(['account_status']);
            $table->dropColumn([
                'approval_status',
                'rejection_reason',
                'account_status',
                'suspension_reason',
                'balance',
                'credit_limit',
            ]);
        });
    }
};
