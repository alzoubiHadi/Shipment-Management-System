<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * UC-22: append-only comment log a driver can add to a shipment they're
 * actively working (e.g. a field problem CRM Admin should know about).
 * Visible to the company on that shipment and to every admin — never
 * edited or deleted, only added to, same append-only pattern as
 * driver_documents.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shipment_comments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('comment');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipment_comments');
    }
};
