import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/Driver.dart';
import '../models/Shipment.dart';
import 'config.dart';


class ShipmentService {




  Future<bool> assignDriver({
    required int shipmentId,
    required int driverId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$baseUrl/shipments/assign/driver'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'driverId': driverId.toString(),
        'shipmentId': shipmentId.toString(),
      }),
    );

    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(
        'Failed to assign driver (HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }
  Future<List<Driver>> fetchDrivers() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/get/drivers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print(response.body);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Driver> drivers = (data['drivers'] as List)
          .map((e) => Driver.fromMap(e))
          .toList();

      return drivers;
    } else {
      throw Exception(
        'Failed to load drivers (HTTP ${response.statusCode})',
      );
    }
  }
  Future<List<Shipment>> fetchShipments() async {
    final prefs = await SharedPreferences.getInstance();
    //
    String? token = prefs.getString('token');
    String? driverid = prefs.getString('id');
    final response = await http.get(
      Uri.parse('${baseUrl}/driver/${driverid}/shipments'),
      headers: {
        'Content-Type': 'application/json',
        // Add auth headers here if needed, e.g.:
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);


    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Shipment> shipments =
      (data['shipments'] as List)
          .map((e) => Shipment.fromJson(e))
          .toList();

      return shipments;
    } else {
      throw Exception(
        'Failed to load shipments (HTTP ${response.statusCode})',
      );
    }
  }
  Future<List<Shipment>> fetchShipmentsadmin() async {
    final prefs = await SharedPreferences.getInstance();
    //
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('${baseUrl}/shipments'),
      headers: {
        'Content-Type': 'application/json',
        // Add auth headers here if needed, e.g.:
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);


    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Shipment> shipments =
      (data['shipments'] as List)
          .map((e) => Shipment.fromJson(e))
          .toList();

      return shipments;
    } else {
      throw Exception(
        'Failed to load shipments (HTTP ${response.statusCode})',
      );
    }
  }
  Future<List<Shipment>> fetchShipmentscompany() async {
    final prefs = await SharedPreferences.getInstance();
    //
    String? token = prefs.getString('token');
    String? companyid = prefs.getString('id');
    final response = await http.get(
      Uri.parse('${baseUrl}/company/${companyid}/shipments'),
      headers: {
        'Content-Type': 'application/json',
        // Add auth headers here if needed, e.g.:
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);


    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Shipment> shipments =
      (data['shipments'] as List)
          .map((e) => Shipment.fromJson(e))
          .toList();

      return shipments;
    } else {
      throw Exception(
        'Failed to load shipments (HTTP ${response.statusCode})',
      );
    }
  }
  Future<bool> updateShipmentStatus({
    required int shipmentId,
    required String status,
    String? cancellationReason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      //
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse(
          '${baseUrl}/shipments/status/change',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
          'shipment_id': shipmentId,
          if (cancellationReason != null)
            'cancellation_reason': cancellationReason,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(
        'Failed: ${response.statusCode}\n${response.body}',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }
  Future<bool> refuseShipment({required int shipmentId, required int status,}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      //
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse(
          '${baseUrl}/shipments/refuse',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
          'shipment_id': shipmentId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(
        'Failed: ${response.statusCode}\n${response.body}',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }
  Future<bool> acceptShipment({required int shipmentId, required int status,}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      //
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse(
          '${baseUrl}/shipments/accept',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
          'shipment_id': shipmentId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(
        'Failed: ${response.statusCode}\n${response.body}',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }
  /// Re-fetch a single shipment by its tracking number. Used to poll for
  /// live updates on the read-only tracking view (admin/company), so a
  /// driver's stage updates show up without the viewer reopening the page.
  Future<Shipment?> fetchOneByTrackingNumber(String trackingNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/shipments/$trackingNumber/track'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Shipment.fromJson(data['shipment']);
    }
    return null;
  }

  /// Driver: move the shipment one step forward in the 7-stage tracking
  /// timeline (stages 1-6). Stage 7 (delivered) uses [deliverShipment].
  Future<Map<String, dynamic>> advanceStage({required int shipmentId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/shipments/$shipmentId/advance-stage'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'shipment': data['shipment'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Driver: final stage — captures the proof-of-delivery signature
  /// (base64-encoded PNG) and the recipient's name.
  Future<Map<String, dynamic>> deliverShipment({
    required int shipmentId,
    required String podSignatureBase64,
    required String recipientName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/shipments/$shipmentId/deliver'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pod_signature': podSignatureBase64,
          'pod_recipient_name': recipientName,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'shipment': data['shipment'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> addShipment({ required Shipment shipment }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      //
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse(
          '${baseUrl}/shipments',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'origin': shipment.origin,
          'destination': shipment.destination,
          'weight': shipment.weight,
          'description': shipment.description,
          'tracking_number': shipment.trackingNumber,
        }),
      );

      if (response.statusCode == 201) {

        return true;
      }

      throw Exception(
        'Failed: ${response.statusCode}\n${response.body}',
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

}