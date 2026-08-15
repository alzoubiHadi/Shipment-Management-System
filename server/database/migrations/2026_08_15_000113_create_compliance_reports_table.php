<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Compliance/safety axis (UC-25/UC-26) — fully separate from the
     * driver's 1-5 service rating. category drives the escalation track:
     * traffic / cargo_damage / complaint escalate Active -> Warning ->
     * Suspended on repeated/verified reports; criminal / smuggling /
     * forgery trigger an immediate freeze (status='under_review',
     * resulting_action='ban_pending') pending Super Admin review. A driver
     * has a right to appeal before any final ban (appeal_text/
     * appeal_status). Super Admin may also suspend directly, skipping
     * escalation, for serious findings without a matching report row.
     */
    public function up(): void
    {
        Schema::create('compliance_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->foreignId('reported_by_user_id')->nullable()->constrained('users')->nullOnDelete();

            $table->enum('category', ['traffic', 'cargo_damage', 'complaint', 'criminal', 'smuggling', 'forgery', 'other']);
            $table->text('description');
            $table->string('evidence_file_path')->nullable();

            $table->enum('status', ['open', 'under_review', 'upheld', 'dismissed'])->default('open');
            $table->enum('resulting_action', ['none', 'warning', 'suspension', 'ban'])->nullable();

            $table->text('appeal_text')->nullable();
            $table->enum('appeal_status', ['none', 'pending', 'accepted', 'rejected'])->default('none');

            $table->foreignId('resolved_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();

            $table->timestamps();

            $table->index(['driver_id', 'status']);
            $table->index('category');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('compliance_reports');
    }
};
