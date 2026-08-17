<?php

namespace App\Http\Controllers;

use App\Http\Resources\CompanyFacingShipmentOfferResource;
use App\Http\Resources\DriverFacingShipmentOfferResource;
use App\Models\Company;
use App\Models\Driver;
use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\Truck;
use App\Models\User;
use App\Notifications\AppPushNotification;
use App\Services\ComplianceService;
use App\Services\LedgerService;
use App\Services\MatchingService;
use App\Services\PricingService;
use App\Support\Destinations;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ShipmentOfferController extends Controller
{
    /**
     * Company: create a new shipment offer directly (UC-11) — no admin
     * middleman. Price is computed automatically from the central price
     * list (UC-12) when destination+truck_type has a row; otherwise the
     * offer goes to 'awaiting_manual_price' and CRM Admin is notified
     * immediately (UC-13). A successfully auto-priced offer starts
     * matching (UC-14) right away.
     */
    public function create(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        if (! $company->isActive()) {
            return response()->json([
                'message' => 'Your company account is not active (pending approval or suspended)',
            ], 403);
        }

        // Compliance/Approval separation feature (2026-08-23), grace-period
        // follow-up (2026-08-24): 'action_required'/'pending_review' always
        // block; 'expiring_soon' is allowed as long as the trade license
        // doesn't expire within the order-type-based grace window (3 days
        // for an internal shipment, 3 months for an external one) — see
        // ComplianceService::isEligibleForShipment(). approval_status/
        // account_status stay untouched either way, so the company can
        // still log in and view existing shipments/tracking/finance/
        // documents/profile (see Company::recomputeComplianceStatus()).
        // order_type isn't validated yet at this point in the method, so a
        // lightweight peek at the raw input (defaulting to 'internal', same
        // default applied below after full validation) is enough here.
        $orderTypeForComplianceCheck = in_array($request->input('order_type'), ['internal', 'external'], true)
            ? $request->input('order_type')
            : 'internal';

        if (! ComplianceService::isEligibleForShipment($company, $orderTypeForComplianceCheck)) {
            $message = match ($company->compliance_status) {
                'expiring_soon' => $orderTypeForComplianceCheck === 'external'
                    ? 'Your trade license expires within 3 months — renew it before creating a new external shipment'
                    : 'Your trade license expires within 3 days — renew it before creating a new shipment',
                'pending_review' => 'Your trade license renewal is still pending admin review',
                default => 'Your trade license has expired — renew it before creating a new shipment',
            };

            return response()->json(['message' => $message], 403);
        }

        try {
            $validated = $request->validate([
                'origin' => ['required', 'string'],
                'origin_lat' => ['nullable', 'numeric'],
                'origin_lng' => ['nullable', 'numeric'],
                'destination' => ['required', 'string'],
                'weight' => ['nullable', 'numeric'],
                'description' => ['nullable', 'string'],
                'needs_permit' => ['boolean'],
                'is_hazardous' => ['boolean'],
                'is_fragile' => ['boolean'],
                'order_type' => ['nullable', 'in:internal,external'],
                'required_truck_type' => ['required', 'string', 'in:' . implode(',', Truck::TRUCK_TYPES)],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $e->errors(),
            ], 422);
        }

        $validated['order_type'] = $validated['order_type'] ?? 'internal';

        // External destinations must match the price matrix exactly so
        // auto-pricing can find a row; internal offers stay free text
        // (there's no internal rate table yet — see App\Support\Destinations).
        if ($validated['order_type'] === 'external' && ! in_array($validated['destination'], Destinations::all(), true)) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => ['destination' => ['Must be one of the supported external destinations.']],
            ], 422);
        }

        // Admin Shipments redesign (2026-08-24): a representative
        // destination coordinate lets the Trip Report / Live Tracking
        // screens show a straight-line distance. Only external offers have
        // a fixed, known destination — internal ones stay free text with
        // no coordinates, so destination_lat/lng are simply left null and
        // the UI omits distance for those rather than guessing.
        if ($validated['order_type'] === 'external') {
            $coords = Destinations::coordsFor($validated['destination']);
            if ($coords) {
                [$validated['destination_lat'], $validated['destination_lng']] = $coords;
            }
        }

        $pricing = app(PricingService::class)->computeAutoPrice($validated['destination'], $validated['required_truck_type']);

        $validated['company_id'] = $company->id;
        // Admin Shipments redesign (2026-08-24): same generation pattern as
        // Shipment's own tracking_number (finalizeAcceptance() below) — a
        // continuous #TRK-xxxxx identity from the moment the offer exists,
        // not only once a driver accepts it.
        $validated['tracking_number'] = 'TRK' . strtoupper(uniqid());
        $validated['status'] = $pricing ? 'pending' : ShipmentOffer::STATUS_AWAITING_MANUAL_PRICE;

        if ($pricing) {
            $validated['pricing_mode'] = 'auto';
            $validated['price_to_driver'] = $pricing['price_to_driver'];
            // Company-facing price defaults to the base (pre-margin) price;
            // the company may raise it later via raisePrice(), never lower it.
            $validated['price_to_client'] = $pricing['base_price'];
            $validated['platform_margin_percent_snapshot'] = $pricing['margin_percent'];

            // Reserve the price against the company's available balance the
            // moment it's known, so a second offer created a second later
            // can't also spend this same headroom before either is
            // accepted/cancelled — see Company::reservedAmount().
            $validated['financial_status'] = 'reserved';
        }

        // Concurrency fix (2026-08-25, financial audit): canAffordOffer()
        // was a plain read with no lock, and the offer (with its
        // reservation) was created afterward with no lock either. Two
        // offers created back to back for the same company could both read
        // the same available balance and both pass the credit-limit check,
        // together reserving more than the company's actual headroom. Fix:
        // lock the Company row as a per-company mutex before checking
        // affordability and creating the offer — manualPrice() and
        // raisePrice() below take this same lock, so any two of these three
        // actions for the same company now serialize instead of racing.
        try {
            $offer = $pricing
                ? DB::transaction(function () use ($company, $validated) {
                    $lockedCompany = Company::where('id', $company->id)->lockForUpdate()->firstOrFail();

                    if (! $lockedCompany->canAffordOffer((float) $validated['price_to_client'])) {
                        throw new \RuntimeException("This shipment would exceed your company's credit limit");
                    }

                    return ShipmentOffer::create($validated);
                })
                : ShipmentOffer::create($validated);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        if ($pricing) {
            app(MatchingService::class)->matchNextBatch($offer);
        } else {
            $this->notifyCrmAdmins($offer);
        }

        return response()->json([
            'message' => 'Shipment offer created successfully',
            'offer' => $offer->fresh(),
        ], 201);
    }

    /**
     * CRM Admin: enter a price manually for an offer stuck in
     * 'awaiting_manual_price' (UC-13) — inside this SAME offer record, not
     * an external channel. Immediately kicks off matching afterward.
     */
    public function manualPrice(Request $request, ShipmentOffer $offer)
    {
        if ($offer->status !== ShipmentOffer::STATUS_AWAITING_MANUAL_PRICE) {
            return response()->json(['message' => 'This offer is not awaiting manual pricing'], 409);
        }

        $validated = $request->validate([
            'price_to_driver' => ['required', 'numeric', 'min:0'],
            'price_to_client' => ['required', 'numeric', 'min:0', 'gte:price_to_driver'],
        ]);

        // Same per-company lock as create() above — this also creates a
        // fresh reservation, so it has to serialize against any other
        // in-flight offer creation/pricing/raise for this same company.
        try {
            DB::transaction(function () use ($offer, $validated, $request) {
                $lockedCompany = Company::where('id', $offer->company_id)->lockForUpdate()->firstOrFail();

                if (! $lockedCompany->canAffordOffer((float) $validated['price_to_client'])) {
                    throw new \RuntimeException("This price would exceed the company's credit limit");
                }

                $offer->update([
                    'price_to_driver' => $validated['price_to_driver'],
                    'price_to_client' => $validated['price_to_client'],
                    'pricing_mode' => 'manual',
                    'priced_by_user_id' => $request->user()->id,
                    'status' => 'pending',
                    'financial_status' => 'reserved',
                ]);
            });
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        app(MatchingService::class)->matchNextBatch($offer);

        return response()->json([
            'message' => 'Price set successfully — matching started',
            'offer' => $offer->fresh(),
        ], 200);
    }

    /**
     * Company: raise (never lower) the price shown to drivers/charged to
     * them, while the offer is still unaccepted.
     */
    public function raisePrice(Request $request, ShipmentOffer $offer)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company || $offer->company_id !== $company->id) {
            return response()->json(['message' => 'This is not your offer'], 403);
        }

        $validated = $request->validate([
            'price_to_client' => ['required', 'numeric'],
        ]);

        if ((float) $validated['price_to_client'] < (float) $offer->price_to_client) {
            return response()->json(['message' => 'The price can only be raised, not lowered'], 422);
        }

        // Same per-company lock as create()/manualPrice() above.
        try {
            DB::transaction(function () use ($offer, $validated) {
                $lockedOffer = ShipmentOffer::where('id', $offer->id)->lockForUpdate()->firstOrFail();

                if ($lockedOffer->status !== 'pending') {
                    throw new \RuntimeException('This offer can no longer be modified');
                }

                $lockedCompany = Company::where('id', $lockedOffer->company_id)->lockForUpdate()->firstOrFail();

                // Exclude this offer's own existing reservation from the
                // check — otherwise its old (lower) price would be
                // double-counted: once as part of the current reservation
                // total, and again as the new price being tested against it.
                if (! $lockedCompany->canAffordOffer((float) $validated['price_to_client'], $lockedOffer->id)) {
                    throw new \RuntimeException("This price would exceed your company's credit limit");
                }

                $lockedOffer->update(['price_to_client' => $validated['price_to_client']]);
            });
        } catch (\RuntimeException $e) {
            $status = $e->getMessage() === 'This offer can no longer be modified' ? 409 : 422;
            return response()->json(['message' => $e->getMessage()], $status);
        }

        return response()->json([
            'message' => 'Price updated successfully',
            'offer' => $offer->fresh(),
        ], 200);
    }

    /**
     * Super Admin: manually push another matching round right now instead
     * of waiting for the timeout (mirrors what the ProcessExpiredMatches
     * scheduled command does automatically — see console command).
     */
    public function rematch(Request $request, ShipmentOffer $offer)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only Super Admin can trigger a manual re-match'], 403);
        }

        if ($offer->status !== 'pending') {
            return response()->json(['message' => 'Only pending offers can be re-matched'], 409);
        }

        $matched = app(MatchingService::class)->matchNextBatch($offer);

        return response()->json([
            'message' => $matched
                ? 'Offer pushed to a new batch of drivers'
                : 'No more eligible drivers — offer escalated to Super Admin',
            'offer' => $offer->fresh(),
            'matched_count' => count($matched),
        ], 200);
    }

    /**
     * Super Admin: hand-assign an escalated offer (every eligible driver
     * exhausted with no acceptance) to a specific known driver — UC-17.
     * Skips the normal availability/eligibility gate since this is an
     * explicit admin override, but the truck itself must still be
     * roadworthy and of the right type.
     */
    public function assignDriver(Request $request, ShipmentOffer $offer)
    {
        if (! $request->user()->isSuperAdmin()) {
            return response()->json(['message' => 'Only Super Admin can manually assign an escalated offer'], 403);
        }

        if ($offer->status !== 'escalated') {
            return response()->json(['message' => 'Only escalated offers can be manually assigned'], 409);
        }

        $validated = $request->validate([
            'driver_id' => ['required', 'exists:drivers,id'],
            'truck_id' => ['required', 'exists:trucks,id'],
        ]);

        return DB::transaction(function () use ($offer, $validated) {
            $offer = ShipmentOffer::lockForUpdate()->findOrFail($offer->id);

            if ($offer->status !== 'escalated') {
                return response()->json(['message' => 'This offer is no longer escalated'], 409);
            }

            $driver = Driver::findOrFail($validated['driver_id']);
            $truck = Truck::findOrFail($validated['truck_id']);

            $truckIssue = $truck->suitabilityIssue($offer);
            if ($truckIssue) {
                return response()->json(['message' => $truckIssue], 422);
            }

            $shipment = $this->finalizeAcceptance($offer, $driver, $truck);

            return response()->json([
                'message' => 'Offer manually assigned to driver',
                'shipment' => $shipment,
            ], 201);
        });
    }

    /**
     * Company app: list only THIS company's own offers (pending, awaiting
     * manual price, accepted, escalated, cancelled, ...).
     */
    public function myOffers(Request $request)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        $offers = ShipmentOffer::where('company_id', $company->id)
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'message' => 'Offers retrieved successfully',
            // Financial audit (2026-08-25): CompanyFacingShipmentOfferResource
            // shows this company its own price_to_client, but never
            // price_to_driver or platform_margin_percent_snapshot.
            'offers' => CompanyFacingShipmentOfferResource::collection($offers),
        ], 200);
    }

    /**
     * Admin: list every offer, with how many eligible drivers currently
     * match it (helps show why an offer might be stuck unmatched).
     *
     * Authorization fix (2026-08-25, financial audit): this only sat behind
     * auth:sanctum with no role check, so any authenticated driver or
     * company could call it directly and read every offer's
     * price_to_client / platform_margin_percent_snapshot for every other
     * company. Restricted to admin/sub-admin — the real audience.
     */
    public function index(Request $request)
    {
        if (! $request->user()->isSuperAdmin() && ! $request->user()->isSubAdmin()) {
            return response()->json(['message' => 'You are not authorized to view all offers'], 403);
        }

        $offers = ShipmentOffer::with(['company', 'acceptedByDriver', 'acceptedTruck'])
            ->orderByDesc('created_at')
            ->get()
            ->map(function (ShipmentOffer $offer) {
                $offer->eligible_drivers_count = $offer->status === 'pending'
                    ? app(MatchingService::class)->eligibleDriversQuery($offer)->count()
                    : 0;

                return $offer;
            });

        return response()->json([
            'message' => 'Shipment offers retrieved successfully',
            'offers' => $offers,
        ], 200);
    }

    /**
     * Admin: preview which drivers are eligible & available for a given
     * offer right now, based on status, document validity, and (for
     * cross-border offers) the 3-month residency rule.
     */
    public function eligibleDrivers(ShipmentOffer $offer)
    {
        $drivers = app(MatchingService::class)->eligibleDriversQuery($offer)->get();

        return response()->json([
            'message' => 'Eligible drivers retrieved successfully',
            'drivers' => $drivers,
        ], 200);
    }

    /**
     * Driver app: list pending offers this specific driver currently
     * qualifies for, so the app can show "available jobs" to that driver.
     * Broader than "only the top-5 matched this round" on purpose — any
     * eligible driver can still pick up a pending offer, matching just
     * decides who gets pushed a notification first. NOT broader than full
     * eligibility, though: this used to show almost every pending internal
     * offer regardless of the driver's truck/route, only checking the
     * cross-border residency rule for external ones. It now reuses
     * MatchingService::eligibleDriversQuery() — the exact same Step 1 hard
     * filter matching runs — so a driver whose truck can't do the job, or
     * who doesn't cover the route, never sees it here at all. One query
     * per pending offer is a deliberate simplicity-over-cleverness choice:
     * pending-offer volume is small enough that this is not a concern, and
     * it guarantees this list can never drift out of sync with what
     * matching itself considers eligible.
     */
    public function availableForDriver($driver_id)
    {
        $driver = Driver::where('user_id', $driver_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $matchingService = app(MatchingService::class);

        $offers = ShipmentOffer::where('status', 'pending')
            ->orderByDesc('created_at')
            ->get()
            ->filter(fn (ShipmentOffer $offer) => $matchingService->eligibleDriversQuery($offer)
                ->whereKey($driver->id)
                ->exists())
            ->values();

        return response()->json([
            'message' => 'Available offers retrieved successfully',
            // Financial audit (2026-08-25): DriverFacingShipmentOfferResource
            // shows this driver their own price_to_driver, but never
            // price_to_client or platform_margin_percent_snapshot — the
            // driver was never meant to see what the company pays or FMS's
            // margin.
            'offers' => DriverFacingShipmentOfferResource::collection($offers),
        ], 200);
    }

    /**
     * Driver app: accept an offer. Turns the offer into a real Shipment,
     * locks the offer so nobody else can take it, and marks the driver as
     * busy.
     *
     * The driver no longer chooses a truck_id — under the Driver 1<->1
     * Truck rule (TruckController::addMyTruck refuses a second truck) there
     * is never a real choice to make, and letting the client send an
     * arbitrary truck_id meant a driver could technically accept using a
     * truck that wasn't even theirs. The flow is now strictly: get the
     * authenticated driver -> get THEIR linked truck -> validate it ->
     * accept.
     */
    public function accept(Request $request)
    {
        $validated = $request->validate([
            'offer_id' => ['required', 'exists:shipment_offers,id'],
        ]);

        // Security fix (2026-08-25, financial audit): this used to trust a
        // client-supplied driver_user_id and resolve the driver from THAT,
        // instead of from the authenticated request. Any logged-in user who
        // knew (or guessed) another driver's user id could accept an offer
        // on that driver's behalf — which immediately posts a real
        // SHIPMENT_CHARGE against the company and later a DRIVER_EARNING
        // for a driver who never actually agreed to the job. The server
        // already knows who is calling; it must never take that identity
        // from the request body.
        $authenticatedDriverUserId = $request->user()->id;

        return DB::transaction(function () use ($validated, $authenticatedDriverUserId) {
            $offer = ShipmentOffer::lockForUpdate()->findOrFail($validated['offer_id']);

            if ($offer->status !== 'pending') {
                return response()->json([
                    'message' => 'This offer is no longer available',
                ], 409);
            }

            $driver = Driver::where('user_id', $authenticatedDriverUserId)->first();

            if (! $driver) {
                return response()->json(['message' => 'Driver not found'], 404);
            }

            if (! $driver->isEligibleForNewJob($offer->order_type)) {
                return response()->json([
                    'message' => 'Driver is not eligible for this job (unavailable, non-compliant, a payout is pending, or a required document is missing/expired)',
                ], 422);
            }

            if ($offer->order_type === 'external' && ! $driver->meetsCrossBorderResidencyRule()) {
                return response()->json([
                    'message' => 'Driver residency does not meet the 3-month cross-border requirement',
                ], 422);
            }

            // Defense in depth: the app's own Available Shipments list
            // already only shows offers whose route this driver covers
            // (see availableForDriver()), but accept() must not simply
            // trust that — re-check here too.
            foreach (app(MatchingService::class)->requiredCountriesFor($offer) as $country) {
                if (! $driver->coversCountry($country)) {
                    return response()->json([
                        'message' => 'Driver does not cover this route',
                    ], 422);
                }
            }

            $truck = $driver->truck;

            if (! $truck) {
                return response()->json(['message' => 'You do not have a registered truck yet'], 422);
            }

            $truckIssue = $truck->suitabilityIssue($offer);
            if ($truckIssue) {
                return response()->json(['message' => $truckIssue], 422);
            }

            // This driver was offered this specific job (matched or not) and
            // accepted it — counts toward their acceptance-rate score even
            // if they were never actually in a matched batch (e.g. picked
            // it up from the general available-offers list).
            $driver->increment('offers_accepted_count');

            $shipment = $this->finalizeAcceptance($offer, $driver, $truck);

            return response()->json([
                'message' => 'Offer accepted, shipment created successfully',
                // Financial audit (2026-08-25): price_to_client (what the
                // company pays) and the platform margin were never meant to
                // reach the driver — same rule as the offer resources
                // above, applied here since accept() returns a real
                // Shipment record, not a ShipmentOffer.
                'shipment' => $shipment->makeHidden('price_to_client'),
            ], 201);
        });
    }

    public function cancel(Request $request, ShipmentOffer $offer)
    {
        if (! in_array($offer->status, ['pending', ShipmentOffer::STATUS_AWAITING_MANUAL_PRICE, 'escalated'], true)) {
            return response()->json([
                'message' => 'Only pending offers can be cancelled',
            ], 409);
        }

        $validated = $request->validate([
            'cancellation_reason' => ['required', 'string'],
        ]);

        $offer->update([
            'status' => 'cancelled',
            'cancellation_reason' => $validated['cancellation_reason'],
            'cancelled_by_user_id' => $request->user()->id,
            'cancelled_at' => now(),
            // Frees the hold on the company's available balance — no
            // ledger transaction was ever posted for this offer, so there
            // is nothing to reverse, only the reservation to release.
            'financial_status' => $offer->financial_status === 'reserved' ? 'released' : $offer->financial_status,
        ]);

        // Admin Shipments redesign (2026-08-24): close out any still-open
        // round so the Matching Status/history doesn't show a phantom
        // "still waiting" round for an offer that's actually cancelled.
        \App\Models\ShipmentOfferMatchingRound::where('shipment_offer_id', $offer->id)
            ->where('outcome', \App\Models\ShipmentOfferMatchingRound::OUTCOME_WAITING)
            ->update(['outcome' => \App\Models\ShipmentOfferMatchingRound::OUTCOME_NO_ACCEPTANCE, 'resolved_at' => now()]);

        return response()->json([
            'message' => 'Offer cancelled successfully',
            'offer' => $offer,
        ], 200);
    }

    /**
     * Turns an offer into a real Shipment and marks the driver busy. Shared
     * by the normal accept() flow and the Super Admin manual-assign
     * override (UC-17) — caller is responsible for validating eligibility
     * appropriately for each path and wrapping this in a DB transaction
     * with the offer row locked.
     */
    private function finalizeAcceptance(ShipmentOffer $offer, Driver $driver, Truck $truck): Shipment
    {
        $trackingNumber = 'TRK' . strtoupper(uniqid());

        $shipment = Shipment::create([
            'shipment_offer_id' => $offer->id,
            'company_id' => $offer->company_id,
            'driver_id' => $driver->id,
            'truck_id' => $truck->id,
            'tracking_number' => $trackingNumber,
            'origin' => $offer->origin,
            'origin_lat' => $offer->origin_lat,
            'origin_lng' => $offer->origin_lng,
            'destination' => $offer->destination,
            'destination_lat' => $offer->destination_lat,
            'destination_lng' => $offer->destination_lng,
            'weight' => $offer->weight,
            'description' => $offer->description,
            'needs_permit' => $offer->needs_permit,
            'is_hazardous' => $offer->is_hazardous,
            'is_fragile' => $offer->is_fragile,
            'order_type' => $offer->order_type,
            'price_to_driver' => $offer->price_to_driver,
            'price_to_client' => $offer->price_to_client,
            'status' => 1, // assigned
        ]);

        $offer->update([
            'status' => 'accepted',
            'accepted_by_driver_id' => $driver->id,
            'accepted_truck_id' => $truck->id,
            'accepted_at' => now(),
            // The reservation converts into a real charge below — net
            // effect on the company's available balance is zero at this
            // exact moment (reserved amount drops by X, balance drops by
            // X), so no fresh canAffordOffer() re-check is needed here.
            'financial_status' => 'committed',
        ]);

        // Admin Shipments redesign (2026-08-24): close out this offer's
        // current matching round as a genuine acceptance, not a timeout —
        // see ShipmentOfferMatchingRound / MatchingService::matchNextBatch().
        \App\Models\ShipmentOfferMatchingRound::where('shipment_offer_id', $offer->id)
            ->where('outcome', \App\Models\ShipmentOfferMatchingRound::OUTCOME_WAITING)
            ->update([
                'outcome' => \App\Models\ShipmentOfferMatchingRound::OUTCOME_ACCEPTED,
                'accepted_by_driver_id' => $driver->id,
                'resolved_at' => now(),
            ]);

        // Company is only actually charged once the shipment is real (a
        // driver has committed to it) — NOT at offer creation, and not
        // merely reserved. This was previously missing entirely: balance
        // only ever went up (deposits), never down for shipment charges.
        app(LedgerService::class)->record(
            $offer->company,
            'SHIPMENT_CHARGE',
            -(float) $offer->price_to_client,
            $shipment,
            "Charged for shipment {$shipment->tracking_number}",
        );

        $driver->update(['status' => 'busy']);

        return $shipment;
    }

    /**
     * UC-13: notify CRM Admin the instant an offer needs manual pricing —
     * every Super Admin plus every sub-admin holding the 'crm' permission.
     */
    private function notifyCrmAdmins(ShipmentOffer $offer): void
    {
        $crmAdmins = User::where('type', 'super_admin')
            ->orWhere('type', 'admin')
            ->orWhere(function ($q) {
                $q->where('type', 'sub_admin')->whereHas('permissions', fn ($p) => $p->where('key', 'crm'));
            })
            ->get();

        foreach ($crmAdmins as $admin) {
            $admin->notify(new AppPushNotification(
                'manual_pricing_required',
                'Offer awaiting manual pricing',
                sprintf('Offer #%d (%s -> %s) has no automatic price and needs one now.', $offer->id, $offer->origin, $offer->destination),
                ['offer_id' => $offer->id],
            ));
        }
    }
}
