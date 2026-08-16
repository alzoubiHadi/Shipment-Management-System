<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * UC-6 add-on: Super Admin can temporarily suspend a sub-admin account
     * (separate from deleting it outright). Kept at the users table level
     * — unlike companies/drivers, which have their own approval workflow —
     * since this only needs a simple on/off switch enforced at login.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_suspended')->default(false)->after('must_change_password');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('is_suspended');
        });
    }
};
