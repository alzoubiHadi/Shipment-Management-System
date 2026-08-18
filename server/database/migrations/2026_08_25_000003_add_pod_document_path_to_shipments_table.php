<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Feature (2026-08-25): replaces the hand-drawn signature captured at
 * delivery (pod_signature, a base64 PNG) with an attached proof-of-delivery
 * document — the driver photographs or uploads a file of the physical
 * delivery note instead of signing on-screen. pod_signature/
 * pod_recipient_name are left in place (not dropped) so already-delivered
 * shipments still have their original signature to show — see
 * ShipmentController::deliver() and AdminShipmentController::show() for
 * where pod_document_path is now written/read alongside them.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            if (! Schema::hasColumn('shipments', 'pod_document_path')) {
                $table->string('pod_document_path')->nullable()->after('pod_recipient_name');
            }
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropColumn('pod_document_path');
        });
    }
};
