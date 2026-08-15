<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * UC-32 alternative flow: driver reports they never actually received a
 * payout Finance Admin marked 'paid' — routes to CRM/Super Admin review
 * instead of silently sitting there. Needs a 'disputed' status value, which
 * means swapping the original enum('pending','paid','confirmed','rejected')
 * column for a plain string column (SQLite enums are CHECK constraints;
 * altering one in place needs doctrine/dbal, which couldn't be
 * verified-installed in the environment this was written in — dropping and
 * re-adding as a string sidesteps that entirely, with the same allowed
 * values enforced in the controller/validation layer instead of the DB).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payout_requests', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn('status');
        });

        Schema::table('payout_requests', function (Blueprint $table) {
            $table->string('status')->default('pending')->after('amount');
            $table->text('dispute_reason')->nullable()->after('rejection_reason');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::table('payout_requests', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn(['status', 'dispute_reason']);
        });

        Schema::table('payout_requests', function (Blueprint $table) {
            $table->enum('status', ['pending', 'paid', 'confirmed', 'rejected'])->default('pending')->after('amount');
            $table->index('status');
        });
    }
};
