<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Unified Approvals / document-expiry feature (2026-08-22): same
     * append-only document history as driver_documents/truck_documents,
     * for companies. Only 'trade_license' exists as a type today
     * (companies.license_file_path/license_expiry mirror the is_current
     * row here, same denormalization pattern as the driver/truck legacy
     * columns) but this is a real table rather than inline columns so a
     * second company document type can be added later without another
     * schema change, and so a company's renewal history is preserved
     * exactly like a driver's or a truck's.
     */
    public function up(): void
    {
        Schema::create('company_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            // trade_license (only type for now)
            $table->string('type')->default('trade_license');
            $table->string('file_path');
            $table->date('expiry_date')->nullable();
            $table->boolean('is_current')->default(true);
            $table->string('status')->default('valid');

            $table->foreignId('uploaded_by_user_id')->nullable()->constrained('users')->nullOnDelete();

            $table->timestamps();

            $table->index(['company_id', 'type', 'is_current']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('company_documents');
    }
};
