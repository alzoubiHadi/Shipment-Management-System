<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * The original seed labels ("Finance Admin", "Trainer Admin", etc.)
     * read redundantly in the UI once each permission is already shown
     * next to an "Admin" role context (SubAdminsPage, UserProfilePage
     * badges) — the user asked for the shorter form ("finance" is
     * enough). Data-only change; the `key` column (used in code/route
     * middleware) is untouched.
     */
    public function up(): void
    {
        $labels = [
            'finance' => 'Finance',
            'trainer' => 'Trainer',
            'technical_check' => 'Technical Check',
            'crm' => 'CRM',
        ];

        foreach ($labels as $key => $label) {
            DB::table('permissions')->where('key', $key)->update(['label' => $label]);
        }
    }

    public function down(): void
    {
        $labels = [
            'finance' => 'Finance Admin',
            'trainer' => 'Trainer Admin',
            'technical_check' => 'Technical Check Admin',
            'crm' => 'CRM Admin',
        ];

        foreach ($labels as $key => $label) {
            DB::table('permissions')->where('key', $key)->update(['label' => $label]);
        }
    }
};
