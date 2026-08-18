<?php

namespace Tests\Feature;

use App\Models\Permission;
use App\Models\ProfileEditRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Covers the category-based permission gate added to ProfileController::
 * approve()/reject()/adminIndex() — trainer reviews only 'document'
 * (driver document renewals), technical_check reviews only
 * 'truck_document', and finance keeps 'company_license'/'destinations',
 * per the user's confirmed scope ("نقطة المدرب والفحص الفني فقط فحص
 * مستندات" — trainer/technical_check are document-review-only roles).
 *
 * Deliberately does NOT set up real Driver/Truck/Company rows: approve()'s
 * apply*() helpers all no-op gracefully when the owning driver/company
 * can't be found (see ProfileController::applyDocument() etc.), so a bare
 * ProfileEditRequest row is enough to exercise the permission gate itself
 * without dragging in unrelated fixtures.
 */
class AdminPermissionsTest extends TestCase
{
    use RefreshDatabase;

    private function makeUser(string $type): User
    {
        return User::create([
            'name' => 'Test User',
            'email' => uniqid('user').'@example.com',
            'password' => Hash::make('password'),
            'type' => $type,
        ]);
    }

    private function makeSubAdmin(array $permissionKeys): User
    {
        $admin = $this->makeUser('sub_admin');
        $ids = Permission::whereIn('key', $permissionKeys)->pluck('id');
        $admin->permissions()->sync($ids);
        return $admin;
    }

    private function makeEditRequest(string $category): ProfileEditRequest
    {
        $owner = $this->makeUser('driver');

        return ProfileEditRequest::create([
            'user_id' => $owner->id,
            'category' => $category,
            'payload' => [],
            'status' => 'pending',
        ]);
    }

    public function test_trainer_can_approve_document_category(): void
    {
        $trainer = $this->makeSubAdmin(['trainer']);
        $request = $this->makeEditRequest('document');

        Sanctum::actingAs($trainer);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve");

        $response->assertStatus(200);
        $this->assertSame('approved', $request->fresh()->status);
    }

    public function test_trainer_cannot_approve_truck_document_category(): void
    {
        $trainer = $this->makeSubAdmin(['trainer']);
        $request = $this->makeEditRequest('truck_document');

        Sanctum::actingAs($trainer);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve");

        $response->assertStatus(403);
        $this->assertSame('pending', $request->fresh()->status);
    }

    public function test_trainer_cannot_approve_company_license_category(): void
    {
        $trainer = $this->makeSubAdmin(['trainer']);
        $request = $this->makeEditRequest('company_license');

        Sanctum::actingAs($trainer);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve");

        $response->assertStatus(403);
    }

    public function test_technical_check_can_approve_truck_document_category(): void
    {
        $technicalCheck = $this->makeSubAdmin(['technical_check']);
        $request = $this->makeEditRequest('truck_document');

        Sanctum::actingAs($technicalCheck);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve");

        $response->assertStatus(200);
        $this->assertSame('approved', $request->fresh()->status);
    }

    public function test_technical_check_cannot_approve_document_category(): void
    {
        $technicalCheck = $this->makeSubAdmin(['technical_check']);
        $request = $this->makeEditRequest('document');

        Sanctum::actingAs($technicalCheck);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve");

        $response->assertStatus(403);
    }

    public function test_finance_can_approve_company_license_and_destinations(): void
    {
        $finance = $this->makeSubAdmin(['finance']);

        Sanctum::actingAs($finance);

        $license = $this->makeEditRequest('company_license');
        $this->putJson("/api/admin/profile-edit-requests/{$license->id}/approve")->assertStatus(200);

        $destinations = $this->makeEditRequest('destinations');
        $this->putJson("/api/admin/profile-edit-requests/{$destinations->id}/approve")->assertStatus(200);
    }

    /**
     * Before this change, a single blanket hasPermission('finance') check
     * covered every category — finance no longer reaches into the two
     * categories that now belong exclusively to trainer/technical_check.
     */
    public function test_finance_cannot_approve_document_category(): void
    {
        $finance = $this->makeSubAdmin(['finance']);
        $request = $this->makeEditRequest('document');

        Sanctum::actingAs($finance);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve");

        $response->assertStatus(403);
    }

    public function test_super_admin_can_approve_and_reject_any_category(): void
    {
        $superAdmin = $this->makeUser('super_admin');
        Sanctum::actingAs($superAdmin);

        foreach (['document', 'truck_document', 'company_license', 'destinations'] as $category) {
            $request = $this->makeEditRequest($category);
            $this->putJson("/api/admin/profile-edit-requests/{$request->id}/approve")->assertStatus(200);
        }

        $rejectRequest = $this->makeEditRequest('document');
        $this->putJson("/api/admin/profile-edit-requests/{$rejectRequest->id}/reject")->assertStatus(200);
        $this->assertSame('rejected', $rejectRequest->fresh()->status);
    }

    public function test_reject_is_also_gated_by_category(): void
    {
        $trainer = $this->makeSubAdmin(['trainer']);
        $request = $this->makeEditRequest('truck_document');

        Sanctum::actingAs($trainer);
        $response = $this->putJson("/api/admin/profile-edit-requests/{$request->id}/reject");

        $response->assertStatus(403);
        $this->assertSame('pending', $request->fresh()->status);
    }

    /**
     * adminIndex() must scope the returned list to only the categories the
     * caller can actually review, even when the client asks for more —
     * a trainer must never see a company_license row (see AdminDrawer's
     * "Work Destinations" hiding and ApprovalsPage's tab hiding on the
     * Flutter side, both built on this same guarantee).
     */
    public function test_admin_index_only_returns_categories_caller_can_review(): void
    {
        $trainer = $this->makeSubAdmin(['trainer']);
        $this->makeEditRequest('document');
        $this->makeEditRequest('truck_document');
        $this->makeEditRequest('company_license');

        Sanctum::actingAs($trainer);
        $response = $this->getJson('/api/admin/profile-edit-requests?status=pending&category=document,truck_document,company_license');

        $response->assertStatus(200);
        $categories = collect($response->json('requests'))->pluck('category')->unique()->values()->all();
        $this->assertSame(['document'], $categories);
    }

    /**
     * A sub-admin with only 'crm' has no overlap with any renewal
     * category at all — adminIndex() should refuse outright (403) rather
     * than silently returning an empty list, so the gate can never be
     * mistaken for "there's just nothing pending right now".
     */
    public function test_admin_index_403_for_admin_with_no_relevant_permission(): void
    {
        $crmAdmin = $this->makeSubAdmin(['crm']);

        Sanctum::actingAs($crmAdmin);
        $response = $this->getJson('/api/admin/profile-edit-requests');

        $response->assertStatus(403);
    }

    public function test_admin_index_allows_super_admin_to_see_everything(): void
    {
        $superAdmin = $this->makeUser('super_admin');
        $this->makeEditRequest('document');
        $this->makeEditRequest('truck_document');
        $this->makeEditRequest('company_license');

        Sanctum::actingAs($superAdmin);
        $response = $this->getJson('/api/admin/profile-edit-requests?status=pending');

        $response->assertStatus(200);
        $this->assertCount(3, $response->json('requests'));
    }
}
