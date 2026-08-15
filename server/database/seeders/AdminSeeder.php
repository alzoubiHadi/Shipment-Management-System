<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@fms.com'],
            [
                'name' => 'System Administrator',
                'email' => 'admin@fms.com',
                'password' => Hash::make('admin123'),
                'type' => 'admin', // Change if your column is different
                // Seeded admin logs straight in — no OTP step, same as
                // admin-created sub-admin accounts (see UserController::login).
                'email_verified_at' => now(),
            ]
        );
    }
}