<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\DriverDestination;
use App\Models\FallbackPricing;
use App\Models\PriceListEntry;
use App\Models\ShipmentOffer;
use App\Models\User;
use App\Models\Zone;
use App\Services\MatchingService;
use App\Services\PricingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Zones / Smart Pricing Engine V1 (2026-08-27) — covers the new
 * zone-based pricing lookup (PricingService::getPriceSuggestion()), the
 * pricing-preview endpoint, order_type auto-derivation and company-chosen
 * pricing in ShipmentOfferController::create(), and the zone-aware
 * country mapping in MatchingService::requiredCountriesFor(). Deliberately
 * creates its own small Zone/PriceListEntry/FallbackPricing fixtures
 * rather than depending on the large real-data seed migrations, so these
 * tests stay deterministic even if the underlying historical dataset
 * changes.
 */
class ZonePricingMatchingTest extends TestCase
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
            'approval_status' => 'approved',
            'account_status' => 'active',
            'compliance_status' => 'active',
            // Generous headroom so canAffordOffer() never blocks these
            // pricing tests — balance/credit_limit both default to 0
            // otherwise, which would reject every priced offer with a 422.
            'balance' => 0,
            'credit_limit' => 100000,
        ]);
    }

    private function makeZone(string $country, ?string $city, string $name): Zone
    {
        return Zone::create([
            'country' => $country,
            'city' => $city,
            'name' => $name,
            'is_active' => true,
        ]);
    }

    // ── PricingService::getPriceSuggestion() ────────────────────────────

    public function test_get_price_suggestion_returns_exact_lane_with_market_adjustment_applied(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('KSA', 'Riyadh', 'ZTEST_RIYADH');

        PriceListEntry::create([
            'origin_zone_id' => $origin->id,
            'destination_zone_id' => $destination->id,
            'truck_type' => 'Trailer 40 FT-12M-Open',
            'reference_price' => 7025,
            'suggested_low' => 6794,
            'suggested_high' => 7163,
            'historical_trip_count' => 33,
            'confidence' => 'High',
            'market_adjustment_percent' => 5,
            'pricing_level' => 'Exact Zone + Truck',
            'is_active' => true,
        ]);

        $result = app(PricingService::class)->getPriceSuggestion($origin->id, $destination->id, 'Trailer 40 FT-12M-Open');

        $this->assertTrue($result['matched']);
        $this->assertSame(7025.0, $result['reference_price']);
        // 7025 * 1.05 = 7376.25
        $this->assertSame(7376.25, $result['suggested_price']);
        $this->assertSame('High', $result['confidence']);
        $this->assertSame(33, $result['sample_size']);
    }

    public function test_get_price_suggestion_falls_back_to_country_level_when_no_exact_lane(): void
    {
        // Deliberately fictional country strings — the real fallback_pricing
        // seed (2026_08_27_000007) already covers UAE/KSA for this truck
        // type, and FallbackPricing has no zone FK (it's matched by the
        // zone's plain `country` string), so reusing a real country pair
        // here would collide with the seeded row's unique constraint.
        $origin = $this->makeZone('ZTESTLAND_A', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('ZTESTLAND_B', 'Tabuk', 'ZTEST_NEOM');

        FallbackPricing::create([
            'origin_country' => 'ZTESTLAND_A',
            'destination_country' => 'ZTESTLAND_B',
            'truck_type' => 'Trailer 40 FT-12M-Open',
            'reference_price' => 6900,
            'typical_low' => 4650,
            'typical_high' => 7000,
            'historical_trip_count' => 133,
            'pricing_level' => 'Country-to-Country + Truck',
        ]);

        $result = app(PricingService::class)->getPriceSuggestion($origin->id, $destination->id, 'Trailer 40 FT-12M-Open');

        $this->assertTrue($result['matched']);
        $this->assertSame(6900.0, $result['reference_price']);
        $this->assertSame(6900.0, $result['suggested_price']); // no market adjustment on fallback
        $this->assertSame('Medium', $result['confidence']); // fallback is never reported High
    }

    public function test_get_price_suggestion_returns_unmatched_when_no_data_at_all(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('SYRIA', 'Idlib', 'ZTEST_IDLIB');

        $result = app(PricingService::class)->getPriceSuggestion($origin->id, $destination->id, 'Car Career');

        $this->assertFalse($result['matched']);
        $this->assertNull($result['suggested_price']);
    }

    // ── POST /shipment-offers/pricing-preview ───────────────────────────

    public function test_pricing_preview_endpoint_returns_suggestion(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('KSA', 'Riyadh', 'ZTEST_RIYADH');

        PriceListEntry::create([
            'origin_zone_id' => $origin->id,
            'destination_zone_id' => $destination->id,
            'truck_type' => 'Trailer 40 FT-12M-Open',
            'reference_price' => 7025,
            'suggested_low' => 6794,
            'suggested_high' => 7163,
            'historical_trip_count' => 33,
            'confidence' => 'High',
            'market_adjustment_percent' => 0,
            'is_active' => true,
        ]);

        $company = $this->makeCompany();
        Sanctum::actingAs(User::find($company->user_id));

        $response = $this->postJson('/api/shipment-offers/pricing-preview', [
            'origin_zone_id' => $origin->id,
            'destination_zone_id' => $destination->id,
            'required_truck_type' => 'Trailer 40 FT-12M-Open',
        ]);

        $response->assertStatus(200);
        $this->assertTrue($response->json('matched'));
        $this->assertEquals(7025, $response->json('suggested_price'));
    }

    // ── POST /shipment-offers (zone-based create) ───────────────────────

    public function test_create_offer_with_same_country_zones_is_internal(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('UAE', 'Abu Dhabi', 'ZTEST_KIZAD');

        PriceListEntry::create([
            'origin_zone_id' => $origin->id,
            'destination_zone_id' => $destination->id,
            'truck_type' => 'Trailer 40 FT-12M-Open',
            'reference_price' => 1900,
            'historical_trip_count' => 50,
            'confidence' => 'High',
            'market_adjustment_percent' => 0,
            'is_active' => true,
        ]);

        $company = $this->makeCompany();
        Sanctum::actingAs(User::find($company->user_id));

        $response = $this->postJson('/api/shipment-offers', [
            'origin' => 'ZTEST_JAFZA, Dubai, UAE',
            'destination' => 'ZTEST_KIZAD, Abu Dhabi, UAE',
            'origin_country' => 'UAE',
            'origin_city' => 'Dubai',
            'origin_zone_id' => $origin->id,
            'destination_country' => 'UAE',
            'destination_city' => 'Abu Dhabi',
            'destination_zone_id' => $destination->id,
            'weight' => 1000,
            'required_truck_type' => 'Trailer 40 FT-12M-Open',
            // Deliberately sent as 'external' — must be overridden by the
            // origin/destination country comparison, not trusted as-is.
            'order_type' => 'external',
        ]);

        $response->assertStatus(201);
        $this->assertSame('internal', $response->json('offer.order_type'));
    }

    public function test_create_offer_with_different_country_zones_is_external(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('KSA', 'Riyadh', 'ZTEST_RIYADH');

        PriceListEntry::create([
            'origin_zone_id' => $origin->id,
            'destination_zone_id' => $destination->id,
            'truck_type' => 'Trailer 40 FT-12M-Open',
            'reference_price' => 7025,
            'historical_trip_count' => 33,
            'confidence' => 'High',
            'market_adjustment_percent' => 0,
            'is_active' => true,
        ]);

        $company = $this->makeCompany();
        Sanctum::actingAs(User::find($company->user_id));

        $response = $this->postJson('/api/shipment-offers', [
            'origin' => 'ZTEST_JAFZA, Dubai, UAE',
            'destination' => 'ZTEST_RIYADH, KSA',
            'origin_country' => 'UAE',
            'origin_city' => 'Dubai',
            'origin_zone_id' => $origin->id,
            'destination_country' => 'KSA',
            'destination_city' => 'Riyadh',
            'destination_zone_id' => $destination->id,
            'weight' => 1000,
            'required_truck_type' => 'Trailer 40 FT-12M-Open',
            'order_type' => 'internal', // must also be overridden the other way
        ]);

        $response->assertStatus(201);
        $this->assertSame('external', $response->json('offer.order_type'));
    }

    /**
     * Design doc point 8/36: the company can choose a price different from
     * the suggestion, but the server always recomputes price_to_driver
     * from whatever the company actually chose — never trusts a
     * client-sent driver price or margin.
     */
    public function test_company_selected_price_drives_driver_price_recalculation(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('KSA', 'Riyadh', 'ZTEST_RIYADH');

        PriceListEntry::create([
            'origin_zone_id' => $origin->id,
            'destination_zone_id' => $destination->id,
            'truck_type' => 'Trailer 40 FT-12M-Open',
            'reference_price' => 7025,
            'historical_trip_count' => 33,
            'confidence' => 'High',
            'market_adjustment_percent' => 0,
            'is_active' => true,
        ]);

        $company = $this->makeCompany();
        Sanctum::actingAs(User::find($company->user_id));

        // 20% platform margin is the default (see PlatformSetting seed) —
        // company chooses 6,000 instead of the 7,025 suggestion.
        $response = $this->postJson('/api/shipment-offers', [
            'origin' => 'ZTEST_JAFZA, Dubai, UAE',
            'destination' => 'ZTEST_RIYADH, KSA',
            'origin_country' => 'UAE',
            'origin_zone_id' => $origin->id,
            'destination_country' => 'KSA',
            'destination_zone_id' => $destination->id,
            'weight' => 1000,
            'required_truck_type' => 'Trailer 40 FT-12M-Open',
            'company_selected_price' => 6000,
        ]);

        $response->assertStatus(201);
        $this->assertEquals(6000, $response->json('offer.price_to_client'));
        $this->assertEquals(4800, $response->json('offer.price_to_driver')); // 6000 - 20%
        $this->assertEquals(7025, $response->json('offer.pricing_reference')); // snapshot unaffected by company's choice
    }

    public function test_create_offer_falls_back_to_manual_pricing_when_no_zone_data_matches(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('SYRIA', 'Idlib', 'ZTEST_IDLIB');
        // No PriceListEntry, no FallbackPricing for this pair at all.

        $company = $this->makeCompany();
        Sanctum::actingAs(User::find($company->user_id));

        $response = $this->postJson('/api/shipment-offers', [
            'origin' => 'ZTEST_JAFZA, Dubai, UAE',
            'destination' => 'ZTEST_IDLIB, Syria',
            'origin_country' => 'UAE',
            'origin_zone_id' => $origin->id,
            'destination_country' => 'SYRIA',
            'destination_zone_id' => $destination->id,
            'weight' => 1000,
            'required_truck_type' => 'Car Career',
        ]);

        $response->assertStatus(201);
        $this->assertSame('awaiting_manual_price', $response->json('offer.status'));
    }

    // ── MatchingService::requiredCountriesFor() ─────────────────────────

    public function test_required_countries_uses_zone_country_mapping_including_qatar(): void
    {
        $origin = $this->makeZone('UAE', 'Dubai', 'ZTEST_JAFZA');
        $destination = $this->makeZone('QATAR', 'Doha', 'ZTEST_DOHA');

        $offer = ShipmentOffer::create([
            'company_id' => $this->makeCompany()->id,
            'origin' => 'ZTEST_JAFZA, Dubai, UAE',
            'destination' => 'ZTEST_DOHA, Qatar',
            'origin_country' => 'UAE',
            'origin_zone_id' => $origin->id,
            'destination_country' => 'QATAR',
            'destination_zone_id' => $destination->id,
            'order_type' => 'external',
            'status' => 'pending',
            'price_to_driver' => 4000,
            'price_to_client' => 5000,
        ]);

        $countries = app(MatchingService::class)->requiredCountriesFor($offer);

        $this->assertEqualsCanonicalizing(['internal_uae', 'qatar'], $countries);
        // Confirms 'qatar' is now a real, selectable DriverDestination key.
        $this->assertArrayHasKey('qatar', DriverDestination::DESTINATIONS);
    }

    public function test_required_countries_falls_back_to_legacy_logic_without_zone_data(): void
    {
        $offer = ShipmentOffer::create([
            'company_id' => $this->makeCompany()->id,
            'origin' => 'Dubai',
            'destination' => 'Riyadh',
            'order_type' => 'external',
            'status' => 'pending',
            'price_to_driver' => 4000,
            'price_to_client' => 5000,
        ]);

        $countries = app(MatchingService::class)->requiredCountriesFor($offer);

        $this->assertEqualsCanonicalizing(['internal_uae', 'saudi_arabia'], $countries);
    }
}
