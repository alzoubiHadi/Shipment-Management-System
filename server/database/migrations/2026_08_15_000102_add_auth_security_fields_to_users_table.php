<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * - must_change_password: forces a sub-admin created by Super Admin to
     *   pick a real password on first login (they start with a one-time
     *   temporary password).
     * - otp_code / otp_expires_at: short-lived email verification code sent
     *   at self-registration time for companies and drivers. Verifying it
     *   sets the existing email_verified_at column (already on this table),
     *   so no separate "verified" flag is needed.
     *
     * users.type also gains two new possible values used going forward:
     * 'super_admin' (was implicitly just 'admin') and 'sub_admin' (a
     * composable admin account whose actual permissions live in the
     * permission_user pivot table). The column stays a plain string, so no
     * schema change is required for that — existing rows with type='admin'
     * are treated as Super Admin for backward compatibility.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('must_change_password')->default(false)->after('password');
            $table->string('otp_code', 10)->nullable()->after('must_change_password');
            $table->timestamp('otp_expires_at')->nullable()->after('otp_code');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['must_change_password', 'otp_code', 'otp_expires_at']);
        });
    }
};
