<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            // internal = employed by the platform-owning transport company
            // external = independent / contracted driver
            $table->enum('employment_type', ['internal', 'external'])
                  ->default('internal')
                  ->after('user_id');

            // used to filter drivers when matching a shipment offer
            $table->enum('status', ['available', 'busy', 'unavailable'])
                  ->default('available')
                  ->after('employment_type');

            // safety / eligibility documents (from project notes)
            $table->date('residency_expiry')->nullable()->after('status');
            $table->date('passport_expiry')->nullable()->after('residency_expiry');
            $table->string('blood_type')->nullable()->after('passport_expiry');

            $table->index('status');
            $table->index('employment_type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropColumn([
                'employment_type',
                'status',
                'residency_expiry',
                'passport_expiry',
                'blood_type',
            ]);
        });
    }
};
