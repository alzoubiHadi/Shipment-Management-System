<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Unified Approvals / document-expiry feature (2026-08-22): dedup
     * bookkeeping for the daily CheckDocumentExpiry command's 30/15/7/1-day
     * notifications, so a document sitting in the same threshold window
     * across multiple daily runs doesn't re-notify every day. One row per
     * (subject_type, subject_id, field) the command watches:
     *   - 'driver' + drivers.id + 'license_expiry'/'passport_expiry'/'residency_expiry'
     *   - 'truck' + trucks.id + 'license_expiry'/'insurance_expiry'/'technical_inspection_expiry'
     *   - 'company' + companies.id + 'license_expiry'
     * A generic key (not a polymorphic FK) on purpose — trucks alone have
     * THREE independently-expiring fields on one row, which a normal
     * Eloquent polymorphic relation (one row = one subject) can't express
     * without pivoting to yet another table per field.
     *
     * last_threshold_days holds the smallest threshold already notified
     * for that field (30/15/7/1), or -1 once the "now expired" notice has
     * fired, so the command only ever sends a given threshold once as the
     * countdown crosses it, and never re-sends "expired" every day
     * forever.
     */
    public function up(): void
    {
        Schema::create('document_expiry_alerts', function (Blueprint $table) {
            $table->id();
            $table->string('subject_type'); // driver | truck | company
            $table->unsignedBigInteger('subject_id');
            $table->string('field');
            $table->integer('last_threshold_days')->nullable();
            $table->timestamps();

            $table->unique(['subject_type', 'subject_id', 'field'], 'document_expiry_alerts_subject_field_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('document_expiry_alerts');
    }
};
