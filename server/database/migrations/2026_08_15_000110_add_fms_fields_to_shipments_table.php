<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Mirrors the shipment_offers flag changes (drop cargo_type, add the
     * three boolean flags + order_type) and adds the delivery/settlement
     * split (UC-19 / UC-20): the driver's own proof-of-delivery action
     * (pod_signature / pod_recipient_name, already added by the tracking
     * migration) only reaches delivery_status = 'awaiting_confirmation'.
     * It does NOT touch the driver's balance. A separate company action
     * (ShipmentController::confirmDelivery, new in Phase 5) sets
     * delivery_status = 'confirmed', stamps company_confirmed_at /
     * company_confirmed_by, and is the ONLY thing that credits
     * drivers.balance. If the company disputes instead, delivery_status
     * becomes 'disputed' and it routes to CRM Admin instead of auto-crediting.
     */
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropColumn('cargo_type');

            $table->boolean('needs_permit')->default(false)->after('description');
            $table->boolean('is_hazardous')->default(false)->after('needs_permit');
            $table->boolean('is_fragile')->default(false)->after('is_hazardous');
            $table->enum('order_type', ['internal', 'external'])->default('internal')->after('is_fragile');

            $table->enum('delivery_status', ['not_delivered', 'awaiting_confirmation', 'confirmed', 'disputed'])
                ->default('not_delivered')
                ->after('delivered_at');
            $table->foreignId('company_confirmed_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('delivery_status');
            $table->timestamp('company_confirmed_at')->nullable()->after('company_confirmed_by_user_id');
            $table->text('dispute_reason')->nullable()->after('company_confirmed_at');

            $table->index('delivery_status');
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropIndex(['delivery_status']);
            $table->dropConstrainedForeignId('company_confirmed_by_user_id');
            $table->dropColumn([
                'needs_permit',
                'is_hazardous',
                'is_fragile',
                'order_type',
                'delivery_status',
                'company_confirmed_at',
                'dispute_reason',
            ]);

            $table->string('cargo_type')->default('normal')->after('description');
        });
    }
};
