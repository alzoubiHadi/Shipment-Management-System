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
 * UC-23/24 (driver ratings) and UC-25/26 (compliance reports + appeal).
 */
class DriverRatingAndComplianceTest extends TestCase
{
    use RefreshDatabase;

    private function makeAdmin(string $type = 'super_admin'): User
    {
        return User::create([
            'name' => 'Admin',
            'email' => uniqid('admin').'@example.com',
            'password' => Hash::make('password'),
            'type' => $type,
        ]);
    }

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
            'status' => 'available',
            'approval_status' => 'approved',
            'compliance_status' => 'active',
            'user_id' => $user->id,
        ], $overrides));

        return [$user, $driver];
    }

    private function makeConfirmedShipment(Company $company, Driver $driver): Shipment
    {
        return Shipment::create([
            'company_id' => $company->id,
            'driver_id' => $driver->id,
            'tracking_number' => uniqid('TRK'),
            'origin' => 'Dubai',
            'destination' => 'Amman',
            'status' => 3,
            'current_stage' => 7,
            'delivery_status' => 'confirmed',
        ]);
    }

    // ── UC-23: company rates driver ─────────────────────────────────────────

    public function test_company_can_rate_driver_after_confirmed_delivery(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeConfirmedShipment($company, $driver);

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/rate-driver", [
            'score' => 5,
            'comment' => 'Great service',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('driver_ratings', [
            'driver_id' => $driver->id,
            'shipment_id' => $shipment->id,
            'source' => 'company',
            'score' => 5,
        ]);
        // A brand-new driver's only rating is a perfect 5 — the
        // recency-weighted average should reflect that, not stay at the 4.5
        // default.
        $this->assertEquals(5.0, (float) $driver->fresh()->rating);
    }

    public function test_company_cannot_rate_a_driver_before_delivery_is_confirmed(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeConfirmedShipment($company, $driver);
        $shipment->update(['delivery_status' => 'awaiting_confirmation']);

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/shipments/{$shipment->id}/rate-driver", ['score' => 4]);

        $response->assertStatus(409);
    }

    public function test_a_shipment_can_only_be_rated_once(): void
    {
        [$companyUser, $company] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        $shipment = $this->makeConfirmedShipment($company, $driver);

        Sanctum::actingAs($companyUser);

        $this->postJson("/api/shipments/{$shipment->id}/rate-driver", ['score' => 5])->assertStatus(201);
        $second = $this->postJson("/api/shipments/{$shipment->id}/rate-driver", ['score' => 1]);

        $second->assertStatus(409);
        $this->assertEquals(5.0, (float) $driver->fresh()->rating);
    }

    // ── UC-24: Super Admin rates driver directly ────────────────────────────

    public function test_super_admin_can_rate_a_driver_directly(): void
    {
        [, $driver] = $this->makeDriverWithUser();
        $admin = $this->makeAdmin();

        Sanctum::actingAs($admin);

        $response = $this->postJson("/api/drivers/{$driver->id}/rate", [
            'score' => 3,
            'comment' => 'Periodic review',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('driver_ratings', [
            'driver_id' => $driver->id,
            'shipment_id' => null,
            'source' => 'super_admin',
            'score' => 3,
        ]);
    }

    public function test_a_company_cannot_rate_a_driver_directly(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/drivers/{$driver->id}/rate", ['score' => 3]);

        $response->assertStatus(403);
    }

    // ── UC-25: compliance reports ────────────────────────────────────────────

    public function test_a_normal_category_report_leaves_the_driver_active_pending_review(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'complaint',
            'description' => 'Was rude to the receiving warehouse staff',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('compliance_reports', [
            'driver_id' => $driver->id,
            'category' => 'complaint',
            'status' => 'open',
        ]);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'active']);
    }

    public function test_an_immediate_freeze_category_suspends_the_driver_instantly(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();

        Sanctum::actingAs($companyUser);

        $response = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'smuggling',
            'description' => 'Suspicious undeclared cargo found at the border',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('compliance_reports', [
            'driver_id' => $driver->id,
            'category' => 'smuggling',
            'status' => 'under_review',
        ]);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'suspended']);
        $this->assertFalse($driver->fresh()->isEligibleForNewJob());
    }

    public function test_super_admin_upholding_a_report_updates_driver_compliance_status(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        Sanctum::actingAs($companyUser);
        $create = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'traffic',
            'description' => 'Reckless driving reported by warehouse security',
        ]);
        $reportId = $create->json('report.id');

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);

        $resolve = $this->postJson("/api/compliance-reports/{$reportId}/resolve", [
            'decision' => 'uphold',
            'resulting_action' => 'suspension',
        ]);

        $resolve->assertStatus(200);
        $this->assertDatabaseHas('compliance_reports', ['id' => $reportId, 'status' => 'upheld', 'resulting_action' => 'suspension']);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'suspended']);
    }

    public function test_dismissing_an_immediate_freeze_report_lifts_the_suspension(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        Sanctum::actingAs($companyUser);
        $create = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'forgery',
            'description' => 'Suspected forged documents',
        ]);
        $reportId = $create->json('report.id');
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'suspended']);

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);

        $resolve = $this->postJson("/api/compliance-reports/{$reportId}/resolve", [
            'decision' => 'dismiss',
        ]);

        $resolve->assertStatus(200);
        $this->assertDatabaseHas('compliance_reports', ['id' => $reportId, 'status' => 'dismissed']);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'active']);
    }

    // ── UC-26: appeal ────────────────────────────────────────────────────────

    public function test_driver_can_appeal_an_upheld_report_and_acceptance_reverts_status(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [$driverUser, $driver] = $this->makeDriverWithUser();
        Sanctum::actingAs($companyUser);
        $create = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'complaint',
            'description' => 'Alleged rudeness',
        ]);
        $reportId = $create->json('report.id');

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);
        $this->postJson("/api/compliance-reports/{$reportId}/resolve", [
            'decision' => 'uphold',
            'resulting_action' => 'warning',
        ]);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'warning']);

        Sanctum::actingAs($driverUser);
        $appeal = $this->postJson("/api/compliance-reports/{$reportId}/appeal", [
            'appeal_text' => 'This never happened, I have a dashcam recording',
        ]);
        $appeal->assertStatus(200);
        $this->assertDatabaseHas('compliance_reports', ['id' => $reportId, 'appeal_status' => 'pending']);

        Sanctum::actingAs($admin);
        $resolveAppeal = $this->postJson("/api/compliance-reports/{$reportId}/resolve-appeal", [
            'decision' => 'accept',
        ]);

        $resolveAppeal->assertStatus(200);
        $this->assertDatabaseHas('compliance_reports', ['id' => $reportId, 'appeal_status' => 'accepted']);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'compliance_status' => 'active']);
    }

    public function test_a_driver_cannot_appeal_a_report_that_is_still_open(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [$driverUser, $driver] = $this->makeDriverWithUser();
        Sanctum::actingAs($companyUser);
        $create = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'complaint',
            'description' => 'Alleged rudeness',
        ]);
        $reportId = $create->json('report.id');

        Sanctum::actingAs($driverUser);
        $appeal = $this->postJson("/api/compliance-reports/{$reportId}/appeal", [
            'appeal_text' => 'Not true',
        ]);

        $appeal->assertStatus(409);
    }

    public function test_a_driver_cannot_appeal_someone_elses_report(): void
    {
        [$companyUser] = $this->makeCompanyWithUser();
        [, $driver] = $this->makeDriverWithUser();
        [$otherDriverUser] = $this->makeDriverWithUser();

        Sanctum::actingAs($companyUser);
        $create = $this->postJson("/api/drivers/{$driver->id}/compliance-reports", [
            'category' => 'complaint',
            'description' => 'Alleged rudeness',
        ]);
        $reportId = $create->json('report.id');

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);
        $this->postJson("/api/compliance-reports/{$reportId}/resolve", [
            'decision' => 'uphold',
            'resulting_action' => 'warning',
        ]);

        Sanctum::actingAs($otherDriverUser);
        $appeal = $this->postJson("/api/compliance-reports/{$reportId}/appeal", [
            'appeal_text' => 'Not my report',
        ]);

        $appeal->assertStatus(403);
    }
}
