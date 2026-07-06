<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Adds the 7-stage tracking timeline fields to shipments:
     * 1 heading to pickup, 2 loaded, 3 en route to border, 4 border cleared,
     * 5 arrived at destination, 6 unloaded, 7 delivered (proof-of-delivery
     * signature, handled by the dedicated deliver() endpoint).
     */
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            if (! Schema::hasColumn('shipments', 'current_stage')) {
                $table->unsignedTinyInteger('current_stage')->default(0)->after('status');
            }
            if (! Schema::hasColumn('shipments', 'heading_to_pickup_at')) {
                $table->timestamp('heading_to_pickup_at')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'loaded_at')) {
                $table->timestamp('loaded_at')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'departed_to_border_at')) {
                $table->timestamp('departed_to_border_at')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'border_cleared_at')) {
                $table->timestamp('border_cleared_at')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'arrived_at_destination_at')) {
                $table->timestamp('arrived_at_destination_at')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'unloaded_at')) {
                $table->timestamp('unloaded_at')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'pod_signature')) {
                $table->longText('pod_signature')->nullable();
            }
            if (! Schema::hasColumn('shipments', 'pod_recipient_name')) {
                $table->string('pod_recipient_name')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropColumn([
                'current_stage',
                'heading_to_pickup_at',
                'loaded_at',
                'departed_to_border_at',
                'border_cleared_at',
                'arrived_at_destination_at',
                'unloaded_at',
                'pod_signature',
                'pod_recipient_name',
            ]);
        });
    }
};
