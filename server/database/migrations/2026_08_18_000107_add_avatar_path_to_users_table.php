<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Self-service profile page: every role (admin/driver/company) can set
     * a small avatar photo. Stored the same way every other upload in this
     * app is — a Laravel-hashed filename under storage/app/public — so the
     * original client filename (which may contain Arabic characters) never
     * touches the filesystem path or this column.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_path')->nullable()->after('is_suspended');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('avatar_path');
        });
    }
};
