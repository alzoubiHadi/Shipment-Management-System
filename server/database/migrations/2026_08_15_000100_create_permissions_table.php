<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Catalog of composable admin permission groups. A single admin (sub)
     * account can hold more than one of these at once (e.g. finance +
     * trainer on the same account) — see permission_user pivot table.
     *
     * Super Admin is NOT one of these rows: it is identified by
     * users.type === 'super_admin' and implicitly has every permission,
     * so it never needs rows here.
     */
    public function up(): void
    {
        Schema::create('permissions', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique(); // finance, trainer, technical_check, crm
            $table->string('label');
            $table->timestamps();
        });

        DB::table('permissions')->insert([
            ['key' => 'finance', 'label' => 'Finance Admin', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'trainer', 'label' => 'Trainer Admin', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'technical_check', 'label' => 'Technical Check Admin', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'crm', 'label' => 'CRM Admin', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('permissions');
    }
};
