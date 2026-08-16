<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * NFR (Security): "سجل تدقيق لكل إجراء حساس" — an audit trail of every
 * sensitive admin action (approvals, rejections, suspensions, financial
 * approvals, permission changes, etc). Append-only: rows are never
 * updated or deleted, only inserted (see ActivityLog::record()).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->id();
            // Nullable + a name snapshot so the log entry still reads
            // correctly even if the acting user account is later deleted.
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('user_name')->nullable();
            // e.g. 'company.suspended', 'driver.approved', 'payout.marked_paid'.
            $table->string('action');
            // The record the action was performed on, e.g. 'Company' / 123.
            $table->string('subject_type')->nullable();
            $table->string('subject_id')->nullable();
            $table->text('description');
            // Extra structured context (old/new values, reason text, etc).
            $table->json('meta')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['subject_type', 'subject_id']);
            $table->index('action');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_logs');
    }
};
