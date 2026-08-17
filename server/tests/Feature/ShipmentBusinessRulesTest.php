<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Automated tests for the core business rules of the freight-broker system:
 * driver eligibility (availability, documents, cross-border residency),
 * truck/cargo matching, the 7-stage tracking timeline, mandatory
 * cancellation reasons, and the commission summary report.
 *
 * These replace repeatedly clicking through the app by hand to confirm the
 * same rules still hold after future changes.
 */
class ShipmentBusinessRulesTest extends TestCase
{
    use RefreshDatabase;

    private function makeCompany(): Company
    {
        $user = User::create([
            'name' => 'Test Company User',
            'email' => uniqid('company').'@example.com',
            'password' => Hash::make('password'),
            'type' => 'company',
        ]);

        return Company::create([
            'name' => 'Test Company',
            'email' => $user->email,
            'phone' => '0000000',
            'user_id' => $user->id,
        ]);
    }

    /**
     * $destinations defaults to just ['internal_uae'] — enough to cover
     * the default (internal) makeOffer() route. Cross-border tests should
     * pass the extra country explicitly (e.g. ['internal_uae',
     * 'saudi_arabia']), matching MatchingService::requiredCountriesFor().
     */
    private function makeDriver(array $overrides = [], array $destinations = ['internal_uae']): array
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
            'status' => 'available',
            'approval_status' => 'approved',
            'compliance_status' => 'active',
            // All three now hard-required for job eligibility (see
            // Driver::documentIssues()) — default to comfortably valid so
            // tests that aren't specifically about document rules don't
            // trip over them; override per-test as needed.
            'license_expiry' => now()->addYear(),
            'passport_expiry' => now()->addYear(),
            'residency_expiry' => now()->addYear(),
            'user_id' => $user->id,
        ], $overrides));

        foreach ($destinations as $country) {
            DriverDestination::create(['driver_id' => $driver->id, 'destination' => $country]);
        }

        return [$user, $driver];
    }

    private function makeTruck(Driver $driver, array $overrides = []): Truck
    {
        return Truck::create(array_merge([
            'truck_number' => uniqid('TRK'),
            'truck_type' => 'Curtain',
            'has_refrigeration' => false,
            'is_active' => true,
            'insurance_expiry' => now()->addYear(),
            'license_expiry' => now()->addYear(),
            'default_driver_id' => $driver->id,
        ], $overrides));
    }

    private function makeOffer(Company $company, array $overrides = []): ShipmentOffer
    {
        return ShipmentOffer::create(array_merge([
            'company_id' => $company->id,
            'origin' => 'Dubai',
            'destination' => 'Riyadh',
            'weight' => 1000,
            'order_type' => 'internal',
            'status' => 'pending',
            'price_to_driver' => 500,
            'price_to_client' => 700,
        ], $overrides));
    }

    // ── Cross-border residency rule ─────────────────────────────────────

    public function test_driver_with_insufficient_residency_is_rejected_for_cross_border_offer(): void
    {
        [$user, $driver] = $this->makeDriver(
            ['residency_expiry' => now()->addDays(30)], // less than the required 3 months
            ['internal_uae', 'saudi_arabia'],
        );
        $this->makeTruck($driver);
        $company = $this->makeCompany();
        $offer = $this->makeOffer($company, ['order_type' => 'external']);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/shipment-offers/accept', [
            'offer_id' => $offer->id,
            'driver_user_id' => $user->id,
        ]);

        $response->assertStatus(422);
        $this->assertStringContainsString('residency', strtolower($response->json('message')));
        $this->assertDatabaseHas('shipment_offers', ['id' => $offer->id, 'status' => 'pending']);
    }

    public function test_driver_with_sufficient_residency_can_accept_cross_border_offer(): void
    {
        [$user, $driver] = $this->makeDriver(
            ['residency_expiry' => now()->addMonths(4)],
            ['internal_uae', 'saudi_arabia'],
        );
        $this->makeTruck($driver);
        $company = $this->makeCompany();
        $offer = $this->makeOffer($company, ['order_type' => 'external']);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/shipment-offers/accept', [
            'offer_id' => $offer->id,
            'driver_user_id' => $user->id,
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('shipment_offers', ['id' => $offer->id, 'status' => 'accepted']);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'status' => 'busy']);
        $this->assertDatabaseHas('shipments', ['shipment_offer_id' => $offer->id]);
    }

    // ── Truck / cargo matching ───────────────────────────────────────────

    public function test_truck_type_mismatch_rejects_offer_acceptance(): void
    {
        [$user, $driver] = $this->makeDriver();
        $this->makeTruck($driver, ['truck_type' => 'Pickup']);
        $company = $this->makeCompany();
        $offer = $this->makeOffer($company, ['required_truck_type' => 'Reefer']);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/shipment-offers/accept', [
            'offer_id' => $offer->id,
            'driver_user_id' => $user->id,
        ]);

        $response->assertStatus(422);
    }

    public function test_refrigerated_cargo_requires_refrigerated_truck(): void
    {
        [$user, $driver] = $this->makeDriver();
        // Refrigeration is implied by truck_type === 'Reefer Trailer' via a
        // model hook (Truck::booted()), so a "Reefer Trailer" truck can
        // never actually be created with has_refrigeration = false through
        // normal Eloquent saves — saveQuietly() bypasses that hook here to
        // simulate the one way this could still happen (a mislabeled row,
        // e.g. from a raw DB write), which is exactly the defensive case
        // Truck::suitabilityIssue()'s refrigeration check exists for.
        $truck = new Truck([
            'truck_number' => uniqid('TRK'),
            'truck_type' => 'Reefer Trailer',
            'has_refrigeration' => false,
            'is_active' => true,
            'insurance_expiry' => now()->addYear(),
            'license_expiry' => now()->addYear(),
            'default_driver_id' => $driver->id,
        ]);
        $truck->saveQuietly();

        $company = $this->makeCompany();
        $offer = $this->makeOffer($company, ['required_truck_type' => 'Reefer Trailer']);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/shipment-offers/accept', [
            'offer_id' => $offer->id,
            'driver_user_id' => $user->id,
        ]);

        $response->assertStatus(422);
    }

    // ── 7-stage tracking timeline ────────────────────────────────────────

    public function test_stages_advance_one_at_a_time_and_stop_before_delivery(): void
    {
        [$user, $driver] = $this->makeDriver();
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
            'current_stage' => 0,
        ]);

        Sanctum::actingAs($user);

        for ($expectedStage = 1; $expectedStage <= 6; $expectedStage++) {
            $response = $this->postJson("/api/shipments/{$shipment->id}/advance-stage");
            $response->assertStatus(200);
            $this->assertEquals($expectedStage, $response->json('shipment.current_stage'));
        }

        // A 7th advance-stage call must be rejected — delivery requires the
        // signature endpoint instead.
        $response = $this->postJson("/api/shipments/{$shipment->id}/advance-stage");
        $response->assertStatus(422);
        $this->assertDatabaseHas('shipments', ['id' => $shipment->id, 'current_stage' => 6]);
    }

    public function test_delivery_requires_unloading_stage_completed_first(): void
    {
        [$user, $driver] = $this->makeDriver();
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
            'current_stage' => 3, // not yet unloaded
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/shipments/{$shipment->id}/deliver", [
            'pod_signature' => 'data:image/png;base64,fake',
            'pod_recipient_name' => 'Ahmad',
        ]);

        $response->assertStatus(422);
    }

    /**
     * UC-19/UC-20 special requirement: the driver's own delivery claim
     * (deliver()) must NOT pay the driver, free them, or mark the shipment
     * "delivered" (status stays whatever it was) — it only records the
     * proof of delivery and hands off to company confirmation. Paying/
     * freeing only happens in confirmDelivery() — see
     * DeliveryConfirmationTest for that half of the flow. This replaced an
     * earlier (incorrect) version of this test that asserted deliver()
     * itself paid and freed the driver, before that bug was fixed.
     */
    public function test_delivery_succeeds_after_unloading_but_does_not_pay_or_free_the_driver(): void
    {
        [$user, $driver] = $this->makeDriver(['status' => 'busy']);
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
            'current_stage' => 6,
            'price_to_driver' => 500,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/shipments/{$shipment->id}/deliver", [
            'pod_signature' => 'data:image/png;base64,fake',
            'pod_recipient_name' => 'Ahmad',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('shipments', [
            'id' => $shipment->id,
            'current_stage' => 7,
            'status' => 1, // still "In Transit" — NOT auto-marked delivered
            'delivery_status' => 'awaiting_confirmation',
            'pod_recipient_name' => 'Ahmad',
        ]);
        // Driver stays busy and unpaid until the company confirms.
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'status' => 'busy', 'balance' => 0]);
    }

    public function test_driver_cannot_advance_a_shipment_that_is_not_theirs(): void
    {
        [, $ownerDriver] = $this->makeDriver();
        [$otherUser] = $this->makeDriver();
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $ownerDriver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
            'current_stage' => 0,
        ]);

        Sanctum::actingAs($otherUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/advance-stage");

        $response->assertStatus(403);
        $this->assertDatabaseHas('shipments', ['id' => $shipment->id, 'current_stage' => 0]);
    }

    // ── Mandatory cancellation reason ────────────────────────────────────

    public function test_cancelling_a_shipment_without_a_reason_is_rejected(): void
    {
        [$user] = $this->makeDriver();
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/shipments/status/change', [
            'shipment_id' => $shipment->id,
            'status' => 4,
        ]);

        $response->assertStatus(422);
        $this->assertDatabaseHas('shipments', ['id' => $shipment->id, 'status' => 1]);
    }

    public function test_cancelling_a_shipment_with_a_reason_succeeds_and_frees_the_driver(): void
    {
        [$user, $driver] = $this->makeDriver(['status' => 'busy']);
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 1,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/shipments/status/change', [
            'shipment_id' => $shipment->id,
            'status' => 4,
            'cancellation_reason' => 'Missing customs paperwork',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('shipments', [
            'id' => $shipment->id,
            'status' => 4,
            'cancellation_reason' => 'Missing customs paperwork',
        ]);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'status' => 'available']);
    }

    // ── Commission summary report ─────────────────────────────────────────

    public function test_commission_summary_only_counts_delivered_shipments(): void
    {
        [$user] = $this->makeDriver();
        $company = $this->makeCompany();

        // Two delivered shipments that should count.
        Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 3, 'price_to_client' => 700, 'price_to_driver' => 500,
        ]);
        Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 3, 'price_to_client' => 1000, 'price_to_driver' => 650,
        ]);

        // A pending shipment that should NOT count toward commission.
        Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 0, 'price_to_client' => 2000, 'price_to_driver' => 100,
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/reports/summary');

        $response->assertStatus(200);
        $this->assertEquals(2, $response->json('delivered_shipments_count'));
        $this->assertEquals(
            (700 - 500) + (1000 - 650), // = 550
            (float) $response->json('total_commission')
        );
    }
}
