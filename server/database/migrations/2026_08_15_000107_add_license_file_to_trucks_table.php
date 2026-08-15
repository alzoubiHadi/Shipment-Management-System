<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Vehicle license (registration) file upload, now required at truck
     * creation time. truck_type stays a plain string column — the 11 fixed
     * types are enforced at the validation layer (see TruckController),
     * not via a DB enum, to avoid a risky column-type change with no PHP
     * runtime available to test a migration rollback in this environment.
     *
     * default_driver_id (existing column) is reinterpreted going forward as
     * the truck's OWNING driver, since only drivers may add trucks now —
     * kept as-is (not renamed) to avoid unnecessary schema churn.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->string('license_file_path')->nullable()->after('license_expiry');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn('license_file_path');
        });
    }
};
