<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Adds the fields needed for the new driver rating & compliance system,
     * financial balance, near-live location (foreground-only, tied to the
     * existing `status` = available/busy/unavailable toggle), and health
     * data (never exposed to companies — enforced in the API resource
     * layer, not the schema).
     *
     * employment_type (internal/external) is dropped: under the new model
     * every driver is an independent operator who owns their own truck(s),
     * so the old "employed by the platform-owning transport company"
     * distinction no longer applies now that ALBA is not a special
     * platform-owning company.
     *
     * rating: recency-weighted average of company + Super Admin ratings,
     * default 4.5 for brand-new drivers per the adopted design.
     *
     * compliance_status: separate axis from rating — active / warning /
     * suspended / banned. Suspended or banned drivers never appear in
     * matching regardless of rating.
     *
     * admin_note: carries a "return application for completion" message
     * from Super Admin without needing a distinct DB-level approval_status
     * value (approval_status stays 'pending' while admin_note is set).
     */
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropIndex(['employment_type']);
            $table->dropColumn('employment_type');

            $table->text('health_conditions')->nullable()->after('blood_type');

            $table->decimal('rating', 3, 2)->default(4.50)->after('health_conditions');

            $table->enum('compliance_status', ['active', 'warning', 'suspended', 'banned'])
                ->default('active')
                ->after('rating');

            $table->decimal('balance', 12, 2)->default(0)->after('compliance_status');

            $table->decimal('last_lat', 10, 7)->nullable()->after('balance');
            $table->decimal('last_lng', 10, 7)->nullable()->after('last_lat');
            $table->timestamp('last_location_at')->nullable()->after('last_lng');

            // Historical acceptance-rate inputs for the weighted matching score.
            $table->unsignedInteger('offers_received_count')->default(0)->after('last_location_at');
            $table->unsignedInteger('offers_accepted_count')->default(0)->after('offers_received_count');

            $table->text('admin_note')->nullable()->after('rejection_reason');

            $table->index('compliance_status');
            $table->index('rating');
        });
    }

    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropIndex(['compliance_status']);
            $table->dropIndex(['rating']);
            $table->dropColumn([
                'health_conditions',
                'rating',
                'compliance_status',
                'balance',
                'last_lat',
                'last_lng',
                'last_location_at',
                'offers_received_count',
                'offers_accepted_count',
                'admin_note',
            ]);

            $table->enum('employment_type', ['internal', 'external'])
                ->default('internal')
                ->after('user_id');
            $table->index('employment_type');
        });
    }
};
