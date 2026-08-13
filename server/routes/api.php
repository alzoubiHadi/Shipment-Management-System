<?php

use App\Http\Controllers\CompanyController;
use App\Http\Controllers\DriverController;
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

// Protected routes
Route::middleware('auth:sanctum')->group(function () {



    // companies Requests
    Route::get('/get/companies', [CompanyController::class, 'index']);
    Route::get('/get/companies/trashed', [CompanyController::class, 'index_trashed']);
    Route::post('/add/companies', [CompanyController::class, 'create']);
    Route::delete('/delete/companies/{company}', [CompanyController::class, 'destroy']);
    Route::put('/restore/companies/{company}', [CompanyController::class, 'restore']);
    Route::put('/update/companies/{company}', [CompanyController::class, 'update']);
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

    // Trucks
    Route::get('/get/trucks', [TruckController::class, 'index']);
    Route::get('/get/trucks/trashed', [TruckController::class, 'index_trashed']);
    Route::post('/add/trucks', [TruckController::class, 'create']);
    Route::put('/update/trucks/{truck}', [TruckController::class, 'update']);
    Route::delete('/delete/trucks/{truck}', [TruckController::class, 'destroy']);
    Route::put('/restore/trucks/{id}', [TruckController::class, 'restore']);
    Route::get('/driver/{driver_user_id}/trucks', [TruckController::class, 'myTrucks']);
    Route::post('/driver/{driver_user_id}/trucks', [TruckController::class, 'addMyTruck']);

    // Shipment Offers (orders taken over phone/email/WhatsApp, offered to drivers)
    Route::get('/shipment-offers', [ShipmentOfferController::class, 'index']);
    Route::post('/shipment-offers', [ShipmentOfferController::class, 'create']);
    Route::get('/shipment-offers/{offer}/eligible-drivers', [ShipmentOfferController::class, 'eligibleDrivers']);
    Route::get('/driver/{driver_id}/available-offers', [ShipmentOfferController::class, 'availableForDriver']);
    Route::post('/shipment-offers/accept', [ShipmentOfferController::class, 'accept']);
    Route::put('/shipment-offers/{offer}/cancel', [ShipmentOfferController::class, 'cancel']);

    // Shipments Requests
    Route::get('/shipments', [ShipmentController::class, 'index']);
    Route::post('/shipments', [ShipmentController::class, 'create']);
    Route::post('/shipments/assign/driver', [ShipmentController::class, 'assignDriver']);
    Route::delete('/shipments/{shipment}', [ShipmentController::class, 'delete']);
    Route::put('/shipments/{shipment}', [ShipmentController::class, 'update']);
    Route::put('/shipments/{id}/restore', [ShipmentController::class, 'restore']);
    Route::get('/shipments/{tracking_number}/track', [ShipmentController::class, 'trackmyshipment']);
    Route::get('/driver/{driver_id}/shipments', [ShipmentController::class, 'drivergetShipments']);
    Route::get('/company/{company_id}/shipments', [ShipmentController::class, 'companygetShipments']);
    Route::post('/shipments/status/change', [ShipmentController::class, 'updateshipmentstatus']);
    Route::post('/shipments/refuse', [ShipmentController::class, 'refuse']);
    Route::post('/shipments/accept', [ShipmentController::class, 'accept']);
    Route::post('/shipments/{shipment}/advance-stage', [ShipmentController::class, 'advanceStage']);
    Route::post('/shipments/{shipment}/deliver', [ShipmentController::class, 'deliver']);

    // Reports
    Route::get('/reports/drivers', [ReportController::class, 'drivers']);
    Route::get('/reports/companies', [ReportController::class, 'companies']);
    Route::get('/reports/summary', [ReportController::class, 'summary']);
    Route::get('/driver/{driver_user_id}/report', [ReportController::class, 'driverSelf']);

});