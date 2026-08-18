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
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
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

    /**
     * Security fix (2026-08-25, financial audit): accept() used to trust a
     * client-supplied driver_user_id and resolve the driver from THAT
     * instead of the authenticated request — letting any logged-in driver
     * accept (and get charged/paid for) an offer "as" another driver simply
     * by guessing their user id. The server must always resolve the driver
     * from the authenticated token; driver_user_id in the request body must
     * have no effect at all now, even if present.
     */
    public function test_accepting_an_offer_uses_the_authenticated_user_not_a_spoofed_driver_user_id(): void
    {
        [$attackerUser, $attackerDriver] = $this->makeDriver();
        $this->makeTruck($attackerDriver);
        [$victimUser, $victimDriver] = $this->makeDriver();
        $this->makeTruck($victimDriver);
        $company = $this->makeCompany();
        $offer = $this->makeOffer($company);

        Sanctum::actingAs($attackerUser);

        $response = $this->postJson('/api/shipment-offers/accept', [
            'offer_id' => $offer->id,
            // Spoofed — this is the victim's user id, not the caller's.
            'driver_user_id' => $victimUser->id,
        ]);

        $response->assertStatus(201);
        // Assigned to the actual authenticated driver (attacker), never the
        // spoofed victim named in the request body.
        $this->assertDatabaseHas('shipments', [
            'shipment_offer_id' => $offer->id,
            'driver_id' => $attackerDriver->id,
        ]);
        $this->assertDatabaseMissing('shipments', [
            'shipment_offer_id' => $offer->id,
            'driver_id' => $victimDriver->id,
        ]);
        $this->assertDatabaseHas('drivers', ['id' => $attackerDriver->id, 'status' => 'busy']);
        $this->assertDatabaseHas('drivers', ['id' => $victimDriver->id, 'status' => 'available']);
    }

    /**
     * Privacy fix (2026-08-25, financial audit): a driver's own list of
     * available offers used to serialize the raw ShipmentOffer model,
     * exposing price_to_client (what the company pays) and
     * platform_margin_percent_snapshot (FMS's cut) — figures a driver was
     * never meant to see. DriverFacingShipmentOfferResource now strips
     * both, keeping only the driver's own price_to_driver.
     */
    public function test_available_offers_for_driver_never_expose_price_to_client_or_margin(): void
    {
        [$user, $driver] = $this->makeDriver();
        $this->makeTruck($driver);
        $company = $this->makeCompany();
        $this->makeOffer($company, ['platform_margin_percent_snapshot' => 15]);

        Sanctum::actingAs($user);

        $response = $this->getJson("/api/driver/{$user->id}/available-offers");

        $response->assertStatus(200);
        $offer = $response->json('offers.0');
        $this->assertNotNull($offer);
        $this->assertArrayNotHasKey('price_to_client', $offer);
        $this->assertArrayNotHasKey('platform_margin_percent_snapshot', $offer);
        $this->assertArrayHasKey('price_to_driver', $offer);
    }

    /**
     * Authorization fix (2026-08-25, financial audit): this legacy endpoint
     * had no role check at all — any authenticated user, including a plain
     * driver, could reassign any shipment to any driver. Restricted to
     * Super Admin; no live screen calls it (see ShipmentController's
     * requireSuperAdmin() docblock).
     */
    public function test_a_non_admin_cannot_call_the_legacy_assign_driver_endpoint(): void
    {
        [$driverUser, $driver] = $this->makeDriver();
        $company = $this->makeCompany();
        $shipment = Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 0,
        ]);

        Sanctum::actingAs($driverUser);

        $response = $this->postJson('/api/shipments/assign/driver', [
            'shipmentId' => $shipment->id,
            'driverId' => $driver->id,
        ]);

        $response->assertStatus(403);
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

        // Stage check runs before the pod_document/pod_recipient_name
        // validation, so an incomplete/empty body is enough to hit it.
        $response = $this->postJson("/api/shipments/{$shipment->id}/deliver", [
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
        Storage::fake('public');

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

        // 2026-08-25: deliver() now takes an attached POD document (photo
        // or file) instead of a drawn signature.
        $response = $this->post("/api/shipments/{$shipment->id}/deliver", [
            'pod_document' => UploadedFile::fake()->image('pod.jpg'),
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
        $this->assertNotNull($shipment->fresh()->pod_document_path);
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

    // ── Reports ──────────────────────────────────────────────────────────
    // 2026-08-26 reports hardening: permission gate on the admin
    // endpoints, IDOR fix on the driver-self endpoint, and the
    // pending_amount/disputed_amount fix. See ReportController.php's
    // docblocks for the full reasoning behind each fix.

    private function makeAdmin(string $type = 'super_admin'): User
    {
        return User::create([
            'name' => 'Admin',
            'email' => uniqid('admin').'@example.com',
            'password' => Hash::make('password'),
            'type' => $type,
        ]);
    }

    public function test_commission_summary_only_counts_delivered_and_confirmed_shipments(): void
    {
        $admin = $this->makeAdmin();
        $company = $this->makeCompany();

        // Two delivered-and-confirmed shipments that should count.
        Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 3, 'delivery_status' => 'confirmed',
            'price_to_client' => 700, 'price_to_driver' => 500,
        ]);
        Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 3, 'delivery_status' => 'confirmed',
            'price_to_client' => 1000, 'price_to_driver' => 650,
        ]);

        // A pending shipment that should NOT count toward commission.
        Shipment::create([
            'company_id' => $company->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 0, 'price_to_client' => 2000, 'price_to_driver' => 100,
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/reports/summary');

        $response->assertStatus(200);
        $this->assertEquals(2, $response->json('delivered_shipments_count'));
        $this->assertEquals(
            (700 - 500) + (1000 - 650), // = 550
            (float) $response->json('total_commission')
        );
    }

    public function test_reports_endpoints_reject_non_admin_users(): void
    {
        [$user] = $this->makeDriver();
        Sanctum::actingAs($user);

        $this->getJson('/api/reports/summary')->assertStatus(403);
        $this->getJson('/api/reports/drivers')->assertStatus(403);
        $this->getJson('/api/reports/companies')->assertStatus(403);
    }

    public function test_reports_endpoints_allow_admin_and_sub_admin(): void
    {
        Sanctum::actingAs($this->makeAdmin('super_admin'));
        $this->getJson('/api/reports/summary')->assertStatus(200);

        Sanctum::actingAs($this->makeAdmin('sub_admin'));
        $this->getJson('/api/reports/summary')->assertStatus(200);
    }

    public function test_driver_cannot_view_another_drivers_report_via_legacy_route(): void
    {
        [$userA] = $this->makeDriver();
        [$userB] = $this->makeDriver();

        Sanctum::actingAs($userA);

        // Own report via the legacy id-based route still works...
        $this->getJson("/api/driver/{$userA->id}/report")->assertStatus(200);

        // ...but another driver's does not (IDOR fix).
        $this->getJson("/api/driver/{$userB->id}/report")->assertStatus(403);
    }

    public function test_admin_can_view_any_drivers_report_via_legacy_route(): void
    {
        [$driverUser] = $this->makeDriver();
        Sanctum::actingAs($this->makeAdmin());

        $this->getJson("/api/driver/{$driverUser->id}/report")->assertStatus(200);
    }

    public function test_my_driver_report_endpoint_returns_own_data(): void
    {
        [$user, $driver] = $this->makeDriver();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/my-driver-report');

        $response->assertStatus(200);
        $this->assertEquals((float) $driver->balance, (float) $response->json('balance'));
    }

    public function test_pending_amount_counts_awaiting_confirmation_regardless_of_status(): void
    {
        [$user, $driver] = $this->makeDriver();
        $company = $this->makeCompany();

        // Bug-fix regression test: this shipment has been delivered by the
        // driver (POD uploaded) but the company hasn't confirmed yet, so
        // `status` is still whatever it was pre-delivery — NOT 3 — while
        // delivery_status is 'awaiting_confirmation'. The old query
        // required status=3 AND delivery_status='awaiting_confirmation', a
        // combination that never actually occurs in this state machine
        // (see ReportController::buildDriverReport()'s docblock), so
        // pending_amount was permanently stuck at 0.
        Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 2, 'delivery_status' => 'awaiting_confirmation',
            'price_to_client' => 900, 'price_to_driver' => 600,
        ]);

        Sanctum::actingAs($user);
        $response = $this->getJson('/api/my-driver-report');

        $response->assertStatus(200);
        $this->assertEquals(600, (float) $response->json('pending_amount'));
        $this->assertEquals(0, (float) $response->json('disputed_amount'));
    }

    public function test_disputed_amount_counts_disputed_shipments_separately(): void
    {
        [$user, $driver] = $this->makeDriver();
        $company = $this->makeCompany();

        Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'A', 'destination' => 'B',
            'status' => 2, 'delivery_status' => 'disputed',
            'price_to_client' => 900, 'price_to_driver' => 600,
        ]);

        Sanctum::actingAs($user);
        $response = $this->getJson('/api/my-driver-report');

        $response->assertStatus(200);
        $this->assertEquals(0, (float) $response->json('pending_amount'));
        $this->assertEquals(600, (float) $response->json('disputed_amount'));
    }
}
