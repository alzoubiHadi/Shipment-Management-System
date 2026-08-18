git add server/database/migrations/2026_08_25_000003_add_pod_document_path_to_shipments_table.php `
        server/app/Models/Shipment.php `
        server/app/Http/Controllers/ShipmentController.php `
        server/app/Http/Controllers/AdminShipmentController.php `
        server/tests/Feature/ShipmentBusinessRulesTest.php `
        app/lib/Screens/PodAttachmentPage.dart `
        app/lib/Screens/SignatureCapturePage.dart `
        app/lib/Screens/ShipmentTrackingPage.dart `
        app/lib/Screens/ProofOfDeliveryPage.dart `
        app/lib/Screens/TripReportScreen.dart `
        app/lib/API/ShipmentServices.dart `
        app/lib/models/Shipment.dart `
        app/pubspec.yaml `
        app/android/app/src/main/AndroidManifest.xml `
        app/ios/Runner/Info.plist

git commit -m "Replace delivery signature with POD photo/file attachment" -m "Driver now attaches a proof-of-delivery document (camera photo or uploaded file: jpg/jpeg/png/pdf) instead of drawing a signature on completion.

Backend:
- New nullable shipments.pod_document_path column (migration).
- deliver() now requires a pod_document file (validated mimes/size) + pod_recipient_name, stores it on the public disk under pod_documents/, and rejects the request with 422 if unloading isn't complete yet.
- AdminShipmentController's trip-report POD block now also returns pod_document_path alongside the legacy signature fields.
- ShipmentBusinessRulesTest updated: delivery test now uploads a fake file via Storage::fake('public') and asserts pod_document_path is set.

Flutter:
- New PodAttachmentPage.dart: take a photo (image_picker, camera) or pick a file (file_picker: jpg/jpeg/png/pdf), enter recipient name, confirm.
- ShipmentServices.deliverShipment() rewritten as a multipart upload (was JSON body with base64 signature).
- ShipmentTrackingPage._captureDelivery() now pushes PodAttachmentPage and calls the new deliverShipment signature.
- ProofOfDeliveryPage (company review) and TripReportScreen's _PodCard (admin trip report) both updated to show the POD document (image preview or 'view file' link for PDFs), falling back to the legacy base64 signature display for shipments delivered before this change.
- Shipment model gained podDocumentPath field.
- Added image_picker dependency; added CAMERA permission (Android) and NSCameraUsageDescription/NSPhotoLibraryUsageDescription (iOS) since neither key existed before and iOS crashes outright without them.
- SignatureCapturePage.dart marked dead code (superseded, no longer referenced) rather than deleted, per existing convention."

git push origin new-design
