<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Self-service profile edits that are "material to eligibility" (a
     * driver renewing an expiring mandatory document, changing their work
     * destinations, or a company renewing its trade license) are never
     * applied straight away — they land here as a pending row, and only a
     * Super/Finance-scope admin approving it actually writes the change
     * into driver_documents / driver_destinations / companies. Basic
     * contact info (name/phone/email) and the avatar are NOT material and
     * stay a direct update on users/drivers/companies — no row here.
     */
    public function up(): void
    {
        Schema::create('profile_edit_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            // 'document' | 'destinations' | 'company_license'
            $table->string('category');
            // Category-specific proposed change, e.g. {"type":"license","file_path":"...","expiry_date":"2027-01-01"}
            $table->json('payload');
            $table->string('status')->default('pending'); // pending | approved | rejected
            $table->text('admin_note')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
            $table->index(['category', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('profile_edit_requests');
    }
};
