<?php

use App\Http\Controllers\ActivityLogController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\AdminDashboardController;
use App\Http\Controllers\AdminShipmentController;
use App\Http\Controllers\ComplianceReportController;
use App\Http\Controllers\CompanyController;
use App\Http\Controllers\DriverController;
use App\Http\Controllers\FinancialAdjustmentController;
use App\Http\Controllers\FinancialTransactionController;
use App\Http\Controllers\DriverRatingController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\PaymentOrderController;
use App\Http\Controllers\PayoutRequestController;
use App\Http\Controllers\PlatformSettingController;
use App\Http\Controllers\PriceListController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\ShipmentController;
use App\Http\Controllers\ShipmentOfferController;
use App\Http\Controllers\TruckController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\Route;



// Public test
Route::get('/ping', function () {
    return response()->json(['message' => 'API is working']);
});

Route::post('/register', [UserController::class, 'register']);
Route::post('/login', [UserController::class, 'login']);
Route::post('/verify-otp', [UserController::class, 'verifyOtp']);
Route::post('/resend-otp', [UserController::class, 'resendOtp']);

// Protected routes
Route::middleware('auth:sanctum')->group(function () {

    Route::post('/change-password', [UserController::class, 'changePassword']);

    // In-app notification center + FCM device-token registration
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markRead']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::post('/me/fcm-token', [NotificationController::class, 'updateFcmToken']);

    // Admin Dashboard "Home" screen — one summary-counts endpoint.
    Route::get('/admin/dashboard-stats', [AdminDashboardController::class, 'stats']);
    // Unified Approvals / document-expiry feature (2026-08-22): the
    // "Documents Expiring Soon" / "Expired Documents" dashboard alert
    // tap-through — affected people, not an approval queue.
    Route::get('/admin/document-alerts', [AdminDashboardController::class, 'documentAlerts']);

    // Central price list (Finance Admin, UC-33) + editable platform settings
    Route::get('/price-list', [PriceListController::class, 'index'])->middleware('permission:finance');
    Route::get('/price-list/export', [PriceListController::class, 'export'])->middleware('permission:finance');
    Route::post('/price-list/import', [PriceListController::class, 'import'])->middleware('permission:finance');
    // Public within the app (any authenticated user) — just the list of
    // valid external-destination strings, needed by the company's offer
    // creation form, not sensitive on its own.
    Route::get('/price-list/destinations', [PriceListController::class, 'destinationOptions']);
    Route::get('/platform-settings', [PlatformSettingController::class, 'index'])->middleware('permission:finance');
    Route::put('/platform-settings/{key}', [PlatformSettingController::class, 'update'])->middleware('permission:finance');

    // Manual balance adjustments — dual control (Finance Admin proposes,
    // Super Admin approves/rejects; enforced again inside the controller
    // for approve/reject since 'permission:finance' alone isn't strict
    // enough for those two).
    Route::get('/financial-adjustments', [FinancialAdjustmentController::class, 'index'])->middleware('permission:finance');
    Route::post('/financial-adjustments', [FinancialAdjustmentController::class, 'store'])->middleware('permission:finance');
    Route::put('/financial-adjustments/{adjustment}/approve', [FinancialAdjustmentController::class, 'approve']);
    Route::put('/financial-adjustments/{adjustment}/reject', [FinancialAdjustmentController::class, 'reject']);

    // Ledger read access — any authenticated company/driver can see their
    // own statement; Finance Admin can pull up any account's.
    Route::get('/my-transactions', [FinancialTransactionController::class, 'myTransactions']);
    Route::get('/financial-transactions', [FinancialTransactionController::class, 'index'])->middleware('permission:finance');

    // Self-service profile page (every role) — name/phone/email/avatar
    // apply immediately; documents/destinations/company license go through
    // the pending-approval queue below instead (dual control, same
    // permission:finance + manual isSuperAdmin() pattern as the manual
    // adjustments above).
    Route::get('/me/profile', [ProfileController::class, 'show']);
    Route::put('/me/profile', [ProfileController::class, 'updateBasic']);
    Route::post('/me/profile/avatar', [ProfileController::class, 'uploadAvatar']);
    Route::get('/me/profile/edit-requests', [ProfileController::class, 'myEditRequests']);
    Route::post('/me/company/license', [ProfileController::class, 'submitCompanyLicense']);
    Route::put('/me/driver/bank-details', [ProfileController::class, 'updateBankDetails']);
    // No route-level permission:finance middleware here anymore — trainer
    // and technical_check admins need this endpoint too, just scoped to
    // their category. adminIndex() does its own per-category permission
    // filtering (see ProfileController::reviewPermissionFor()).
    Route::get('/admin/profile-edit-requests', [ProfileController::class, 'adminIndex']);
    Route::put('/admin/profile-edit-requests/{profileEditRequest}/approve', [ProfileController::class, 'approve']);
    Route::put('/admin/profile-edit-requests/{profileEditRequest}/reject', [ProfileController::class, 'reject']);

    // Composable admin permissions (Super Admin only in practice — the
    // frontend hides this from sub-admins, and each individual endpoint
    // below is further gated by the relevant 'permission:<key>' middleware
    // once each admin area is wired up in later phases).
    // NFR (Security): audit log — Super Admin only (gated inside the controller).
    Route::get('/activity-logs', [ActivityLogController::class, 'index']);

    Route::get('/admin/permissions', [AdminController::class, 'permissions']);
    Route::get('/admin/sub-admins', [AdminController::class, 'index']);
    Route::post('/admin/sub-admins', [AdminController::class, 'store']);
    Route::put('/admin/sub-admins/{admin}/permissions', [AdminController::class, 'updatePermissions']);
    Route::post('/admin/sub-admins/{admin}/reset-password', [AdminController::class, 'resetPassword']);
    Route::put('/admin/sub-admins/{admin}/suspend', [AdminController::class, 'suspend']);
    Route::put('/admin/sub-admins/{admin}/activate', [AdminController::class, 'activate']);
    Route::delete('/admin/sub-admins/{admin}', [AdminController::class, 'destroy']);

    // companies Requests
    Route::get('/my-company', [CompanyController::class, 'myCompany']);
    Route::get('/get/companies', [CompanyController::class, 'index']);
    Route::get('/get/companies/trashed', [CompanyController::class, 'index_trashed']);
    Route::post('/add/companies', [CompanyController::class, 'create']);
    Route::delete('/delete/companies/{company}', [CompanyController::class, 'destroy']);
    Route::put('/restore/companies/{company}', [CompanyController::class, 'restore']);
    Route::put('/update/companies/{company}', [CompanyController::class, 'update']);
    Route::put('/companies/{company}/approve', [CompanyController::class, 'approve']);
    Route::put('/companies/{company}/reject', [CompanyController::class, 'reject']);
    Route::put('/companies/{company}/return-for-completion', [CompanyController::class, 'returnForCompletion']);
    // Self-service edit + resubmit while approval_status === 'changes_required'
    Route::put('/me/company-registration', [CompanyController::class, 'updateCompanyInfo']);
    Route::post('/me/company-registration/resubmit', [CompanyController::class, 'resubmit']);
    Route::put('/companies/{company}/suspend', [CompanyController::class, 'suspend']);
    Route::put('/companies/{company}/activate', [CompanyController::class, 'activate']);
    Route::put('/companies/{company}/credit-limit', [CompanyController::class, 'setCreditLimit'])->middleware('permission:finance');
    // Drivers Requests
    Route::get('/get/drivers', [DriverController::class, 'index']);
    Route::get('/get/drivers/trashed', [DriverController::class, 'index_trashed']);
    Route::post('/add/drivers', [DriverController::class, 'create']);
    Route::delete('/delete/drivers/{driver}', [DriverController::class, 'destroy']);
   Route::put('/restore/drivers/{id}', [DriverController::class, 'restore']);
    Route::put('/update/drivers/{driver}', [DriverController::class, 'update']);
    Route::put('/drivers/{driver}/status', [DriverController::class, 'updateStatus']);
    Route::put('/drivers/{driver}/approve', [DriverController::class, 'approve']);
    Route::put('/drivers/{driver}/reject', [DriverController::class, 'reject']);
    Route::put('/drivers/{driver}/return-for-completion', [DriverController::class, 'returnForCompletion']);
    // Admin request-review screen (Phase 3): a specific driver's truck.
    Route::get('/drivers/{driver}/truck', [DriverController::class, 'truck']);
    // Self-service edit + resubmit while approval_status === 'changes_required'
    Route::put('/me/driver-registration', [DriverController::class, 'updateDriverInfo']);
    Route::post('/me/driver-registration/resubmit', [DriverController::class, 'resubmit']);
    Route::put('/drivers/{driver}/suspend', [DriverController::class, 'suspend']);
    Route::put('/drivers/{driver}/reactivate', [DriverController::class, 'reactivate']);
    // UC-24: Super Admin rates a driver directly (no shipment attached).
    Route::post('/drivers/{driver}/rate', [DriverRatingController::class, 'rateBySuperAdmin']);
    Route::get('/drivers/{driver}/ratings', [DriverRatingController::class, 'driverRatings']);
    // UC-25/26: compliance/safety reports and driver appeals.
    Route::post('/drivers/{driver}/compliance-reports', [ComplianceReportController::class, 'store']);
    Route::get('/compliance-reports', [ComplianceReportController::class, 'index']);
    Route::get('/my-compliance-reports', [ComplianceReportController::class, 'myReports']);
    Route::post('/compliance-reports/{report}/resolve', [ComplianceReportController::class, 'resolve']);
    Route::post('/compliance-reports/{report}/appeal', [ComplianceReportController::class, 'appeal']);
    Route::post('/compliance-reports/{report}/resolve-appeal', [ComplianceReportController::class, 'resolveAppeal']);
    // Driver documents (append-only, UC-8) and destinations
    Route::get('/driver/{driver_user_id}/documents', [DriverController::class, 'documents']);
    Route::post('/driver/{driver_user_id}/documents', [DriverController::class, 'uploadDocument']);
    Route::get('/driver/destination-options', [DriverController::class, 'destinationOptions']);
    Route::get('/driver/{driver_user_id}/destinations', [DriverController::class, 'myDestinations']);
    Route::put('/driver/{driver_user_id}/destinations', [DriverController::class, 'syncDestinations']);

    // Trucks
    Route::get('/truck-types', [TruckController::class, 'truckTypes']);
    Route::get('/get/trucks', [TruckController::class, 'index']);
    Route::get('/get/trucks/trashed', [TruckController::class, 'index_trashed']);
    Route::post('/add/trucks', [TruckController::class, 'create']);
    Route::put('/update/trucks/{truck}', [TruckController::class, 'update']);
    Route::delete('/delete/trucks/{truck}', [TruckController::class, 'destroy']);
    Route::put('/restore/trucks/{id}', [TruckController::class, 'restore']);
    Route::get('/driver/{driver_user_id}/trucks', [TruckController::class, 'myTrucks']);
    Route::post('/driver/{driver_user_id}/trucks', [TruckController::class, 'addMyTruck']);
    Route::put('/driver/{driver_user_id}/my-truck', [TruckController::class, 'updateMyTruck']);
    // Truck documents (append-only, Unified Approvals feature 2026-08-22) —
    // license/insurance/technical_inspection renewal, previously had no
    // workflow at all outside the changes_required edit window.
    Route::get('/driver/{driver_user_id}/truck-documents', [TruckController::class, 'myTruckDocuments']);
    Route::post('/driver/{driver_user_id}/truck-documents', [TruckController::class, 'uploadMyTruckDocument']);

    // Shipment Offers — companies create these directly (UC-11)
    Route::get('/shipment-offers', [ShipmentOfferController::class, 'index']);
    Route::get('/my-shipment-offers', [ShipmentOfferController::class, 'myOffers']);
    Route::post('/shipment-offers', [ShipmentOfferController::class, 'create']);
    Route::get('/shipment-offers/{offer}/eligible-drivers', [ShipmentOfferController::class, 'eligibleDrivers']);
    Route::get('/driver/{driver_id}/available-offers', [ShipmentOfferController::class, 'availableForDriver']);
    Route::post('/shipment-offers/accept', [ShipmentOfferController::class, 'accept']);
    Route::put('/shipment-offers/{offer}/cancel', [ShipmentOfferController::class, 'cancel']);
    Route::post('/shipment-offers/{offer}/manual-price', [ShipmentOfferController::class, 'manualPrice'])->middleware('permission:crm');
    Route::put('/shipment-offers/{offer}/raise-price', [ShipmentOfferController::class, 'raisePrice']);
    Route::post('/shipment-offers/{offer}/rematch', [ShipmentOfferController::class, 'rematch']);
    Route::post('/shipment-offers/{offer}/assign-driver', [ShipmentOfferController::class, 'assignDriver']);

    // Admin Shipments redesign (2026-08-24): unified list (merges
    // still-matching offers + real shipments into one feed) + status-aware
    // detail, keyed by the shared tracking_number — see AdminShipmentController.
    Route::get('/admin/shipments', [AdminShipmentController::class, 'index']);
    Route::get('/admin/shipments/{trackingNumber}', [AdminShipmentController::class, 'show']);

    // Shipments Requests
    Route::get('/shipments', [ShipmentController::class, 'index']);
    Route::post('/shipments', [ShipmentController::class, 'create']);
    Route::post('/shipments/assign/driver', [ShipmentController::class, 'assignDriver']);
    Route::delete('/shipments/{shipment}', [ShipmentController::class, 'delete']);
    Route::put('/shipments/{shipment}', [ShipmentController::class, 'update']);
    Route::put('/shipments/{id}/restore', [ShipmentController::class, 'restore']);
    Route::get('/shipments/{tracking_number}/track', [ShipmentController::class, 'trackmyshipment']);
    Route::get('/driver/{driver_id}/shipments', [ShipmentController::class, 'drivergetShipments']);
    // Background-tracking gate + "can't Logout mid-trip" rule (Flutter:
    // DriverLocationReporter.dart / logout_helper.dart) — lightweight poll,
    // much cheaper than fetching the driver's full shipment list.
    Route::get('/driver/{driver_id}/current-trip', [ShipmentController::class, 'currentActiveTrip']);
    Route::get('/company/{company_id}/shipments', [ShipmentController::class, 'companygetShipments']);
    Route::post('/shipments/status/change', [ShipmentController::class, 'updateshipmentstatus']);
    Route::post('/shipments/refuse', [ShipmentController::class, 'refuse']);
    // 2026-08-25 (financial audit): removed a dead '/shipments/accept'
    // route that pointed at ShipmentController::accept(), a method that
    // doesn't exist on this controller — it would have thrown a fatal
    // error if ever actually called. No live screen calls it (the real
    // driver-accept flow is ShipmentOfferController::accept()).
    Route::post('/shipments/{shipment}/advance-stage', [ShipmentController::class, 'advanceStage']);
    Route::post('/shipments/{shipment}/deliver', [ShipmentController::class, 'deliver']);
    // UC-20: company confirms/disputes a delivered shipment; Super/CRM Admin
    // settles a disputed one.
    Route::post('/shipments/{shipment}/confirm-delivery', [ShipmentController::class, 'confirmDelivery']);
    Route::post('/shipments/{shipment}/dispute-delivery', [ShipmentController::class, 'disputeDelivery']);
    Route::post('/shipments/{shipment}/resolve-dispute', [ShipmentController::class, 'resolveDispute']);
    // UC-22: append-only field comments on a shipment.
    Route::get('/shipments/{shipment}/comments', [ShipmentController::class, 'listComments']);
    Route::post('/shipments/{shipment}/comments', [ShipmentController::class, 'addComment']);
    // UC-23: company rates the driver after confirming delivery.
    Route::post('/shipments/{shipment}/rate-driver', [DriverRatingController::class, 'rateByCompany']);
    // UC-21/UC-14: driver's near-live foreground location.
    Route::put('/driver/{driver_user_id}/location', [DriverController::class, 'updateLocation']);
    // UC-10: driver toggles their own "available for work" status.
    Route::put('/driver/{driver_user_id}/status', [DriverController::class, 'updateMyStatus']);

    // Payment orders — company top-ups (UC-28/UC-29). Finance Admin-only
    // actions gated by permission:finance; company's own submit/list are
    // any-authenticated-company (scoped to their own company_id inside
    // the controller, same pattern as shipment offers).
    Route::post('/payment-orders', [PaymentOrderController::class, 'create']);
    Route::get('/my-payment-orders', [PaymentOrderController::class, 'myOrders']);
    Route::get('/payment-orders', [PaymentOrderController::class, 'index'])->middleware('permission:finance');
    Route::post('/payment-orders/{order}/approve', [PaymentOrderController::class, 'approve'])->middleware('permission:finance');
    Route::post('/payment-orders/{order}/reject', [PaymentOrderController::class, 'reject'])->middleware('permission:finance');
    // 2026-08-25 (financial audit): receipt now lives on the private disk —
    // ownership/permission check happens inside the controller itself
    // (owning company OR finance permission), same as every other
    // company-scoped endpoint in this file, so no ->middleware() here.
    Route::get('/payment-orders/{order}/receipt', [PaymentOrderController::class, 'downloadReceipt']);

    // Payout requests — driver withdrawals (UC-30/31/32).
    Route::post('/payout-requests', [PayoutRequestController::class, 'create']);
    Route::get('/my-payout-requests', [PayoutRequestController::class, 'myRequests']);
    Route::put('/payout-requests/{payout}/cancel', [PayoutRequestController::class, 'cancel']);
    Route::post('/payout-requests/{payout}/confirm', [PayoutRequestController::class, 'confirmReceipt']);
    Route::post('/payout-requests/{payout}/dispute', [PayoutRequestController::class, 'disputeReceipt']);
    // 2026-08-25 (financial audit): same private-disk pattern as the
    // payment-order receipt above.
    Route::get('/payout-requests/{payout}/receipt', [PayoutRequestController::class, 'downloadReceipt']);
    Route::get('/payout-requests', [PayoutRequestController::class, 'index'])->middleware('permission:finance');
    Route::post('/payout-requests/{payout}/mark-paid', [PayoutRequestController::class, 'markPaid'])->middleware('permission:finance');
    Route::post('/payout-requests/{payout}/reject', [PayoutRequestController::class, 'reject'])->middleware('permission:finance');
    Route::post('/payout-requests/{payout}/resolve-dispute', [PayoutRequestController::class, 'resolveDispute'])->middleware('permission:finance');

    // Reports
    // Admin-only (isSuperAdmin/isSubAdmin — see ReportController::requireAdmin());
    // authorization is enforced inside the controller rather than route
    // middleware since it also needs to allow a driver to read their own
    // report via driverSelf() below.
    Route::get('/reports/drivers', [ReportController::class, 'drivers']);
    Route::get('/reports/companies', [ReportController::class, 'companies']);
    Route::get('/reports/summary', [ReportController::class, 'summary']);
    // IDOR fix (2026-08-26): prefer this over the id-based route below —
    // it resolves the driver from the authenticated user, not a
    // client-supplied id, so there's nothing to forge.
    Route::get('/my-driver-report', [ReportController::class, 'myReport']);
    // Kept for backward compatibility; now checks the caller owns this id
    // (or is an admin) — see ReportController::driverSelf().
    Route::get('/driver/{driver_user_id}/report', [ReportController::class, 'driverSelf']);

});