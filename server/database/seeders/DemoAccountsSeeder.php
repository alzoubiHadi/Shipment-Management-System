<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Demo/test accounts requested for manual QA — 2 more companies and 8 more
 * drivers, all pre-verified (email_verified_at set, same trick as
 * AdminSeeder) so login skips the OTP step entirely, and pre-approved so
 * they're immediately usable rather than sitting in the admin's pending
 * queue. Every field beyond the given email/password is a placeholder —
 * safe to edit after the fact from the app itself.
 *
 * Run with: php artisan db:seed --class=Database\\Seeders\\DemoAccountsSeeder
 */
class DemoAccountsSeeder extends Seeder
{
    public function run(): void
    {
        $companies = [
            ['email' => 'Company2@fms.com', 'password' => 'company@2', 'name' => 'Demo Company 2'],
            ['email' => 'Company3@fms.com', 'password' => 'company@3', 'name' => 'Demo Company 3'],
        ];

        foreach ($companies as $c) {
            $user = User::updateOrCreate(
                ['email' => $c['email']],
                [
                    'name' => $c['name'],
                    'password' => Hash::make($c['password']),
                    'type' => 'company',
                    'email_verified_at' => now(),
                ]
            );

            Company::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'name' => $c['name'],
                    'email' => $c['email'],
                    'phone' => '0500000000',
                    'address' => 'Demo address',
                    'approval_status' => 'approved',
                    'account_status' => 'active',
                    'balance' => 50000,
                    'credit_limit' => 20000,
                ]
            );
        }

        // A mix of truck types (including two Reefer Trailers, to exercise
        // the reefer-matching fix) so these accounts are actually useful
        // for testing different offer scenarios, not just "login works".
        $truckTypes = [
            'Reefer Trailer',
            '3 Ton pick up',
            'Trailer 40 FT-12M-Box',
            'Reefer Trailer',
            'Curtain Trailer 13.5M',
            '10 Ton pick up',
            'Lowbed Trailer - 25 Tons',
            'Trailer 50 FT-15M-Open',
        ];
        $bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

        for ($i = 2; $i <= 9; $i++) {
            $email = "Driver{$i}@fms.com";
            $password = "driver@{$i}";
            $name = "Demo Driver {$i}";

            $user = User::updateOrCreate(
                ['email' => $email],
                [
                    'name' => $name,
                    'password' => Hash::make($password),
                    'type' => 'driver',
                    'email_verified_at' => now(),
                ]
            );

            $driver = Driver::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'name' => $name,
                    'phone' => '05000000' . str_pad((string) $i, 2, '0', STR_PAD_LEFT),
                    'nationality' => 'UAE',
                    'age' => 30,
                    'driver_license' => "DL-DEMO-{$i}",
                    'license_expiry' => now()->addYears(2)->toDateString(),
                    'passport_expiry' => now()->addYears(2)->toDateString(),
                    'residency_expiry' => now()->addYears(2)->toDateString(),
                    'blood_type' => $bloodTypes[($i - 2) % count($bloodTypes)],
                    'status' => 'available',
                    'approval_status' => 'approved',
                    'compliance_status' => 'active',
                ]
            );

            // Eligible for every destination, so these accounts always show
            // up as matches during testing regardless of the offer's route.
            DriverDestination::where('driver_id', $driver->id)->delete();
            foreach (array_keys(DriverDestination::DESTINATIONS) as $destination) {
                DriverDestination::create(['driver_id' => $driver->id, 'destination' => $destination]);
            }

            if (! Truck::where('default_driver_id', $driver->id)->exists()) {
                Truck::create([
                    'truck_number' => "DEMO-TRK-{$i}",
                    'truck_type' => $truckTypes[($i - 2) % count($truckTypes)],
                    'default_driver_id' => $driver->id,
                    'is_active' => true,
                    // has_refrigeration is auto-derived from truck_type by
                    // Truck::booted() — not set explicitly here on purpose.
                ]);
            }
        }
    }
}
