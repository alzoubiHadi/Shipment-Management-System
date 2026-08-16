<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Trade/commercial license file for self-registered companies, mirroring
     * the single-file-per-record pattern already used for trucks
     * (trucks.license_file_path — see TruckController::create/addMyTruck),
     * rather than the more elaborate versioned driver_documents table (UC-8),
     * since a company only needs one current license on file, not a history
     * of document types with revision tracking.
     *
     * Nullable because existing companies (registered before this feature)
     * have no file on record; new self-registrations require it at the
     * UserController::register() level (application code), not here.
     */
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->string('license_file_path')->nullable()->after('rejection_reason');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn('license_file_path');
        });
    }
};
