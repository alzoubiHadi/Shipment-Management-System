<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Driver;
use App\Models\PayoutRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * UC-28..UC-32: the financial system — company top-ups (PaymentOrder) and
 * driver payouts (PayoutRequest). Covers the two production-blocking bugs
 * found while building this: companies.credit_limit defaulting to 0 with
 * no way to raise it, and drivers being able to accept new jobs while a
 * payout was still mid-flight.
 */
class FinancialSystemTest extends TestCase
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

    private function makeCompanyWithUser(array $overrides = []): array
    {
        $user = User::create([
            'name' => 'Test Company User',
            'email' => uniqid('company').'@example.com',
            'password' => Hash::make('password'),
            'type' => 'company',
        ]);

        $company = Company::create(array_merge([
            'name' => 'Test Company',
            'email' => $user->email,
            'phone' => '0000000',
            'user_id' => $user->id,
            'approval_status' => 'approved',
            'account_status' => 'active',
        ], $overrides));

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
            'balance' => 0,
            'user_id' => $user->id,
        ], $overrides));

        return [$user, $driver];
    }

    // ── Company credit limit (UC-11/UC-29 special requirement) ─────────────

    public function test_company_starts_with_zero_credit_limit_and_cannot_afford_any_priced_offer(): void
    {
        [, $company] = $this->makeCompanyWithUser();

        $this->assertSame(0.0, (float) $company->credit_limit);
        $this->assertFalse($company->canAffordOffer(1.0));
    }

    public function test_super_admin_can_set_a_companys_credit_limit(): void
    {
        [, $company] = $this->makeCompanyWithUser();
        $admin = $this->makeAdmin();

        Sanctum::actingAs($admin);

        $response = $this->putJson("/api/companies/{$company->id}/credit-limit", [
            'credit_limit' => 5000,
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('companies', ['id' => $company->id, 'credit_limit' => 5000]);
        $this->assertTrue($company->fresh()->canAffordOffer(5000));
        $this->assertFalse($company->fresh()->canAffordOffer(5000.01));
    }

    // ── PaymentOrder (top-ups) ──────────────────────────────────────────────

    public function test_approving_a_payment_order_credits_the_companys_balance(): void
    {
        Storage::fake('public');

        [$companyUser, $company] = $this->makeCompanyWithUser();
        Sanctum::actingAs($companyUser);

        $create = $this->post('/api/payment-orders', [
            'amount' => 1000,
            'receipt_file' => UploadedFile::fake()->create('receipt.pdf', 100),
        ]);
        $create->assertStatus(201);
        $orderId = $create->json('order.id');

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);

        $approve = $this->postJson("/api/payment-orders/{$orderId}/approve");

        $approve->assertStatus(200);
        $this->assertDatabaseHas('companies', ['id' => $company->id, 'balance' => 1000]);
        $this->assertDatabaseHas('payment_orders', ['id' => $orderId, 'status' => 'approved']);
    }

    public function test_rejecting_a_payment_order_leaves_balance_untouched(): void
    {
        Storage::fake('public');

        [$companyUser, $company] = $this->makeCompanyWithUser();
        Sanctum::actingAs($companyUser);

        $create = $this->post('/api/payment-orders', [
            'amount' => 1000,
            'receipt_file' => UploadedFile::fake()->create('receipt.pdf', 100),
        ]);
        $orderId = $create->json('order.id');

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);

        $reject = $this->postJson("/api/payment-orders/{$orderId}/reject", [
            'rejection_reason' => 'Receipt unreadable',
        ]);

        $reject->assertStatus(200);
        $this->assertDatabaseHas('companies', ['id' => $company->id, 'balance' => 0]);
    }

    // ── PayoutRequest (driver withdrawals) ──────────────────────────────────

    public function test_driver_cannot_request_a_second_payout_while_one_is_pending(): void
    {
        [$driverUser, $driver] = $this->makeDriverWithUser(['balance' => 1000]);
        Sanctum::actingAs($driverUser);

        $first = $this->postJson('/api/payout-requests', ['amount' => 300]);
        $first->assertStatus(201);

        $second = $this->postJson('/api/payout-requests', ['amount' => 200]);
        $second->assertStatus(409);
    }

    public function test_driver_cannot_request_more_than_their_balance(): void
    {
        [$driverUser] = $this->makeDriverWithUser(['balance' => 100]);
        Sanctum::actingAs($driverUser);

        $response = $this->postJson('/api/payout-requests', ['amount' => 500]);

        $response->assertStatus(422);
    }

    public function test_full_payout_lifecycle_decrements_balance_and_unblocks_new_jobs(): void
    {
        Storage::fake('public');

        [$driverUser, $driver] = $this->makeDriverWithUser(['balance' => 1000]);
        Sanctum::actingAs($driverUser);

        $create = $this->postJson('/api/payout-requests', ['amount' => 400]);
        $create->assertStatus(201);
        $payoutId = $create->json('payout.id');

        $this->assertTrue($driver->fresh()->hasPendingPayout());

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);

        $markPaid = $this->post("/api/payout-requests/{$payoutId}/mark-paid", [
            'transfer_receipt_file' => UploadedFile::fake()->create('transfer.pdf', 100),
        ]);
        $markPaid->assertStatus(200);

        // Balance is NOT decremented until the driver confirms.
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 1000]);
        $this->assertTrue($driver->fresh()->hasPendingPayout());

        Sanctum::actingAs($driverUser);
        $confirm = $this->postJson("/api/payout-requests/{$payoutId}/confirm");

        $confirm->assertStatus(200);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 600]);
        $this->assertFalse($driver->fresh()->hasPendingPayout());
    }

    public function test_disputing_a_payout_keeps_the_new_job_lock_until_resolved(): void
    {
        Storage::fake('public');

        [$driverUser, $driver] = $this->makeDriverWithUser(['balance' => 1000]);
        Sanctum::actingAs($driverUser);

        $create = $this->postJson('/api/payout-requests', ['amount' => 400]);
        $payoutId = $create->json('payout.id');

        $admin = $this->makeAdmin();
        Sanctum::actingAs($admin);
        $this->post("/api/payout-requests/{$payoutId}/mark-paid", [
            'transfer_receipt_file' => UploadedFile::fake()->create('transfer.pdf', 100),
        ]);

        Sanctum::actingAs($driverUser);
        $dispute = $this->postJson("/api/payout-requests/{$payoutId}/dispute", [
            'dispute_reason' => 'Never received the transfer',
        ]);
        $dispute->assertStatus(200);
        $this->assertTrue($driver->fresh()->hasPendingPayout());
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 1000]);

        Sanctum::actingAs($admin);
        $resolve = $this->postJson("/api/payout-requests/{$payoutId}/resolve-dispute", [
            'resolution' => 'confirm',
        ]);
        $resolve->assertStatus(200);
        $this->assertDatabaseHas('drivers', ['id' => $driver->id, 'balance' => 600]);
        $this->assertFalse($driver->fresh()->hasPendingPayout());
    }

    public function test_a_suspended_driver_never_appears_eligible_for_new_jobs_even_with_zero_payouts(): void
    {
        [, $driver] = $this->makeDriverWithUser(['compliance_status' => 'suspended']);

        $this->assertFalse($driver->isEligibleForNewJob());
    }
}
