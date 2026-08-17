<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Unified Approvals / document-expiry feature (2026-08-22): companies
     * gain their own compliance axis, set ONLY by
     * Company::recomputeComplianceStatus() when the trade license (the
     * only renewable company document today — see company_documents) is
     * expired. Deliberately a plain string, not a Postgres enum/CHECK
     * constraint (only two values ever, and the project's own convention
     * — see ShipmentOffer::status's migration note — is to avoid the
     * enum-widening dance for values expected to grow later).
     *
     * This is fully separate from account_status (admin-initiated
     * suspension for a rules violation): a company can be
     * compliance_status = 'action_required' while account_status stays
     * 'active', and vice versa. ShipmentOfferController::create() is the
     * only place that reads this new column (blocks creating a NEW
     * shipment offer; existing shipments/tracking/finance/documents/
     * profile are all untouched).
     *
     * license_expiry mirrors the pattern already used for
     * drivers.license_expiry/passport_expiry/residency_expiry: a
     * denormalized "current value" column kept in sync with the new
     * company_documents table's is_current row, so eligibility-style
     * checks don't need a join.
     */
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->string('compliance_status')->default('active')->after('account_status');
            $table->date('license_expiry')->nullable()->after('license_file_path');

            $table->index('compliance_status');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropIndex(['compliance_status']);
            $table->dropColumn(['compliance_status', 'license_expiry']);
        });
    }
};
