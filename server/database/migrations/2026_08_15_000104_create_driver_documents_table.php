<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Append-only / versioned document history for a driver (license,
     * passport, residency, ID, medical certificate, etc.). Per the client's
     * explicit rule: a driver NEVER deletes an expired document, they only
     * upload a new one. The new row becomes the "current" one for its
     * `type` and the old row is kept forever for audit purposes
     * (is_current flips to false instead of any delete).
     *
     * Auto-blocking (UC-8 / Driver::documentIssues) now reads is_current
     * rows only and flips the driver to blocked automatically the moment
     * expiry_date passes — no manual admin action needed.
     */
    public function up(): void
    {
        Schema::create('driver_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();

            // license, passport, residency, id_card, medical_certificate, other
            $table->string('type');
            $table->string('file_path');
            $table->date('expiry_date')->nullable();
            $table->boolean('is_current')->default(true);

            $table->foreignId('uploaded_by_user_id')->nullable()->constrained('users')->nullOnDelete();

            $table->timestamps();

            $table->index(['driver_id', 'type', 'is_current']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_documents');
    }
};
