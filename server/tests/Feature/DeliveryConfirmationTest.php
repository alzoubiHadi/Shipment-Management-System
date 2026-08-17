<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Driver;
use App\Models\Shipment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * UC-19/UC-20: the company-confirmation half of the delivery flow. See
 * ShipmentBusinessRulesTest for the driver's deliver() half. Covers the
 * production bug fixed in this project — driver payment/availability being
 * gated on company confirmation, never on the driver's own delivery claim —
 * plus the dispute alternative flow (UC-20 alt) and its resolution.
 */
class DeliveryConfirmationTest extends TestCase
{
    use RefreshDatabase;

    private function makeCompanyWithUser(): array
    {
        $user = User::create([
            'name' => 'Test Company User',
            'email' => uniqid('company').'@example.com',
            'password' => Hash::make('password'),
            'type' => 'company',
        ]);

        $company = Company::create([
            'name' => 'Test Company',
            'email' => $user->email,
            'phone' => '0000000',
            'user_id' => $user->id,
            'approval_status' => 'approved',
            'account_status' => 'active',
        ]);

        return [$user, $company];
    }

    private function makeDriverWithUser(array $overrides = []): array
    {
        $user = User::create([
            'name' => 'Test Driver',
            'email' => uniqid('driver').'@example.com',
            'password' => Hash::make('password'),
            'type' => 'driver',
        ]);

        $driver = Driver::create(array_merge([
            'name' => 'Test Driver',
            'phone' => '0000000',
            'driver_license' => uniqid('LIC'),
            'status' => 'busy',
            'approval_status' => 'approved',
            'compliance_status' => 'active',
            'balance' => 0,
            'user_id' => $user->id,
        ], $overrides));

        return [$user, $driver];
    }

    private function makeAwaitingConfirmationShipment(Company $company, Driver $driver): Shipment
    {
        return Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
            'current_stage' => 7,
            'delivery_status' => 'awaiting_confirmation',
            'price_to_driver' => 500,
            'price_to_client' => 700,
        ]);
    }

    public function test_company_confirming_delivery_pays_the_driver_and_frees_them(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/confirm-delivery");

        $response->assertStatus(200);
        $this->assertDatabaseHas('shipments', [
            'id' => $shipment->id,
            'status' => 3, // delivered
            'delivery_status' => 'confirmed',
        ]);
        $this->assertDatabaseHas('drivers', [
            'id' => $driver->id,
            'status' => 'available',
            'balance' => 500,
        ]);
    }

    public function test_a_company_cannot_confirm_another_companys_shipment(): void
    {
        [, $company] = $this->makeCompanyWithUser();
        [$otherCompanyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);

        Sanctum::actingAs($otherCompanyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/confirm-delivery");

        $response->assertStatus(403);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 0]);
    }

    public function test_confirming_a_shipment_that_is_not_awaiting_confirmation_is_rejected(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);
        $shipment->update(['delivery_status' => 'not_delivered']);

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/confirm-delivery");

        $response->assertStatus(409);
    }

    public function test_disputing_delivery_does_not_pay_or_free_the_driver(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/dispute-delivery", [
            'dispute_reason' => 'Missing two pallets',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('shipments', [
            'id' => $shipment->id,
            'delivery_status' => 'disputed',
            'dispute_reason' => 'Missing two pallets',
        ]);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'status' => 'busy', 'balance' => 0]);
    }

    public function test_resolving_a_dispute_in_favor_of_the_driver_pays_and_frees_them(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);
        $shipment->disputeDelivery('Claimed missing items');

        $admin = User::create([
            'name' => 'Super Admin',
            'email' => uniqid('admin').'@example.com',
            'password' => Hash::make('password'),
            'type' => 'super_admin',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->postJson("/api/shipments/{$shipment->id}/resolve-dispute", [
            'resolution' => 'confirm',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'status' => 'available', 'balance' => 500]);
    }

    public function test_resolving_a_dispute_against_the_driver_frees_them_without_paying(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);
        $shipment->disputeDelivery('Claimed missing items');

        $admin = User::create([
            'name' => 'Super Admin',
            'email' => uniqid('admin').'@example.com',
            'password' => Hash::make('password'),
            'type' => 'super_admin',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->postJson("/api/shipments/{$shipment->id}/resolve-dispute", [
            'resolution' => 'reject',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'status' => 'available', 'balance' => 0]);
    }

    public function test_a_non_admin_cannot_resolve_a_dispute(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);
        $shipment->disputeDelivery('Claimed missing items');

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/resolve-dispute", [
            'resolution' => 'confirm',
        ]);

        $response->assertStatus(403);
    }

    /**
     * Regression test for the double-credit race fixed 2026-08-25
     * (financial audit): confirmDelivery() used to check delivery_status
     * BEFORE opening its DB transaction, then never re-check it after
     * locking the shipment row — so two near-simultaneous "Confirm
     * delivery" taps could both pass the check and both post a
     * DRIVER_EARNING credit for the same shipment. A sequential double-call
     * here can't reproduce the exact timing of two simultaneous requests,
     * but it does prove the fix's actual guarantee: the second call, once
     * the first has already moved delivery_status off 'awaiting_confirmation',
     * must be rejected and must NOT credit the driver again.
     */
    public function test_confirming_delivery_twice_only_pays_the_driver_once(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeAwaitingConfirmationShipment($company, $driver);

        Sanctum::actingAs($companyUser);

        $first = $this->postJson("/api/shipments/{$shipment->id}/confirm-delivery");
        $first->assertStatus(200);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 500]);

        $second = $this->postJson("/api/shipments/{$shipment->id}/confirm-delivery");
        $second->assertStatus(409);
        // Still 500, not 1000 — the second call did not pay the driver again.
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 500]);
        $this->assertSame(1, \App\Models\FinancialTransaction::where('reference_type', 'Shipment')
            ->where('reference_id', $shipment->id)
            ->where('transaction_type', 'DRIVER_EARNING')
            ->count());
    }
}
