<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Load-balancing input for the matching score (UC-14): a driver who
     * was just pushed an offer a moment ago gets a small penalty relative
     * to one who hasn't been matched in a while, so the same top-rated
     * drivers aren't always favored.
     */
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->timestamp('last_matched_at')->nullable()->after('offers_accepted_count');
        });
    }

    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropColumn('last_matched_at');
        });
    }
};
