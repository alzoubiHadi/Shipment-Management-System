<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * drivers.truck_number / truck_type are legacy columns from before the
     * dedicated `trucks` table existed. A driver's truck is now managed
     * separately (see trucks table) and is no longer collected at
     * registration time, so these columns can no longer be required.
     */
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            // still unique, but SQLite allows multiple NULLs in a unique
            // column (NULL is never considered equal to NULL), so this is
            // safe for the many drivers who won't have a value here yet.
            $table->string('truck_number')->nullable()->change();
            $table->string('truck_type')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->string('truck_number')->nullable(false)->change();
            $table->string('truck_type')->nullable(false)->change();
        });
    }
};
