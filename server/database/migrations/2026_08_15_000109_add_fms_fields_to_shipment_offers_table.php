<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Replaces the old single `cargo_type` enum-ish string with three
     * independent boolean flags (a shipment can be hazardous AND fragile
     * at once, which the old single value could not express), and replaces
     * `requires_cross_border` with an explicit order_type so future order
     * types beyond internal/external can be added without another boolean.
     *
     * Refrigeration is no longer a flag here — it is implied by the company
     * choosing required_truck_type = "Reefer Trailer".
     *
     * pricing_mode / priced_by / platform_margin_percent_snapshot support
     * UC-12/UC-13: 'auto' when price_list_entries has a matching row,
     * 'manual' when CRM Admin entered the price directly on this same
     * offer record after the awaiting_manual_price status. The margin
     * percent is snapshotted at pricing time so later changes to the
     * platform-wide setting don't retroactively change historical offers.
     *
     * status keeps being a plain string column (no DB enum) so the new
     * 'awaiting_manual_price' value needs no schema change — only
     * application-level validation.
     */
    public function up(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropIndex(['cargo_type']);
            $table->dropColumn(['cargo_type', 'requires_cross_border']);

            $table->boolean('needs_permit')->default(false)->after('required_truck_type');
            $table->boolean('is_hazardous')->default(false)->after('needs_permit');
            $table->boolean('is_fragile')->default(false)->after('is_hazardous');
            $table->enum('order_type', ['internal', 'external'])->default('internal')->after('is_fragile');

            $table->enum('pricing_mode', ['auto', 'manual'])->nullable()->after('price_to_client');
            $table->foreignId('priced_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('pricing_mode');
            $table->decimal('platform_margin_percent_snapshot', 5, 2)->nullable()->after('priced_by_user_id');
        });
    }

    public function down(): void
    {
        Schema::table('shipment_offers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('priced_by_user_id');
            $table->dropColumn([
                'needs_permit',
                'is_hazardous',
                'is_fragile',
                'order_type',
                'pricing_mode',
                'platform_margin_percent_snapshot',
            ]);

            $table->string('cargo_type')->default('normal')->after('description');
            $table->boolean('requires_cross_border')->default(false)->after('cargo_type');
            $table->index('cargo_type');
        });
    }
};
