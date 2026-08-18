<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Bug fix (2026-08-18 deploy failure): 2026_08_15_000108 created
     * `destination` and `base_price` as NOT NULL (no default) — nothing in
     * the Zones migrations (2026_08_27_000004 onward) ever relaxed that,
     * so 2026_08_27_000006's 737-row zone-lane seed (which deliberately
     * leaves both columns null on every row it creates — see that
     * migration's docblock) fails production's not-null constraint outright:
     *
     *   SQLSTATE[23502]: Not null violation: 7 ERROR: null value in column
     *   "destination" of relation "price_list_entries" violates not-null
     *   constraint
     *
     * Deliberately dated 2026-08-26 (a day before the whole 2026_08_27_*
     * Zones batch) so it always runs before 2026_08_27_000006, regardless
     * of how far that batch got on a given deploy attempt.
     *
     * `truck_type` stays required — it's populated on both the legacy and
     * zone-based rows (see PriceListEntry model docblock). The existing
     * unique(['destination','truck_type']) index is unaffected: Postgres
     * treats NULL as distinct from any other value in a unique index, so
     * hundreds of zone rows sharing the same truck_type with a null
     * destination don't collide with each other or with legacy rows.
     */
    public function up(): void
    {
        Schema::table('price_list_entries', function (Blueprint $table) {
            $table->string('destination')->nullable()->change();
            $table->decimal('base_price', 10, 2)->nullable()->change();
        });
    }

    public function down(): void
    {
        // Not reversible without either deleting the zone-based rows this
        // unblocks or supplying fake values — intentionally left as a
        // no-op, same reasoning as 2026_08_27_000002's down().
    }
};
