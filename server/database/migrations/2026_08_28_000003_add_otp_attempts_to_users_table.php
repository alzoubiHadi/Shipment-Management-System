<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * 2026-08-28 (security): per-account guess counter for verifyOtp(),
     * paired with the IP-based throttle on the /verify-otp route (see
     * routes/api.php). otp_attempts increments on every wrong code and
     * blocks further checking once it reaches
     * UserController::MAX_OTP_ATTEMPTS, forcing a resend (which issues a
     * fresh code and resets this back to 0) — this closes off unlimited
     * guessing of the 6-digit code for a single known account, which the
     * IP throttle alone doesn't prevent (an attacker could rotate IPs).
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedTinyInteger('otp_attempts')->default(0)->after('otp_expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('otp_attempts');
        });
    }
};
