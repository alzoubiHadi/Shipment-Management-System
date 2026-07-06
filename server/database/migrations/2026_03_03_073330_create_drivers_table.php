<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('drivers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('phone')->nullable()->index();

            $table->string('truck_number')->unique();
            $table->string('truck_type');                 // NOT unique
            $table->string('nationality')->nullable();    // NOT unique
            $table->unsignedTinyInteger('age')->nullable(); // NOT unique

            $table->string('driver_license')->unique();
            $table->date('license_expiry')->nullable();

            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete(); // if driver logs in
            $table->timestamps();
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('drivers');
    }
};
