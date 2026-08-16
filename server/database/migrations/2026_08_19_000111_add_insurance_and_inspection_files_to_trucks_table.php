<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * New-registration-design batch (2026-08-19): the truck documents step
     * now collects insurance and a technical inspection certificate as
     * separate mandatory uploads, alongside the existing vehicle license.
     * insurance_expiry already existed (date-only, no file) — this adds the
     * matching file column plus a brand-new inspection expiry+file pair,
     * following the exact same flat-column pattern as license_file_path
     * rather than introducing a polymorphic truck_documents table.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->string('insurance_file_path')->nullable()->after('insurance_expiry');
            $table->date('technical_inspection_expiry')->nullable()->after('license_file_path');
            $table->string('technical_inspection_file_path')->nullable()->after('technical_inspection_expiry');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn(['insurance_file_path', 'technical_inspection_expiry', 'technical_inspection_file_path']);
        });
    }
};
