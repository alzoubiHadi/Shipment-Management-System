<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Unified Approvals / document-expiry feature (2026-08-22): trucks get
     * the same append-only document history driver_documents already gives
     * drivers — there was previously no renewal workflow for a truck's
     * license/insurance/technical-inspection at all (TruckController::
     * updateMyTruck only allows edits while the driver's approval_status
     * is 'changes_required'). Mirrors driver_documents column-for-column;
     * see that table's migration for the is_current/status contract.
     */
    public function up(): void
    {
        Schema::create('truck_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('truck_id')->constrained()->cascadeOnDelete();

            // license, insurance, technical_inspection
            $table->string('type');
            $table->string('file_path');
            $table->date('expiry_date')->nullable();
            $table->boolean('is_current')->default(true);
            $table->string('status')->default('valid');

            $table->foreignId('uploaded_by_user_id')->nullable()->constrained('users')->nullOnDelete();

            $table->timestamps();

            $table->index(['truck_id', 'type', 'is_current']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('truck_documents');
    }
};
