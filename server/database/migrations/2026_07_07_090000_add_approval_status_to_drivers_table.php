<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Adds an admin-approval workflow for drivers, separate from the
     * existing `status` column (which is about work availability, not
     * account approval). Self-registered drivers now start out as
     * 'pending' until an admin reviews them; drivers created directly by
     * an admin (AddDriverPage) default to 'approved' since the admin is
     * already vouching for them at creation time.
     */
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->enum('approval_status', ['pending', 'approved', 'rejected'])
                ->default('approved')
                ->after('status');

            $table->string('rejection_reason')->nullable()->after('approval_status');

            $table->index('approval_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropIndex(['approval_status']);
            $table->dropColumn(['approval_status', 'rejection_reason']);
        });
    }
};
