import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cod_charge_result.dart';
import '../utils/constants.dart';

enum WeightUnit {
  grams('g'),
  kilograms('kg');

  const WeightUnit(this.label);
  final String label;
}

/// Fetches COD charges from the backend API.
/// Falls back to built-in Sri Lanka Post tiers when
/// [AppConstants.codCalculateApiUrl] is empty.
class CodChargeService {
  CodChargeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static double normalizeWeightToKg(double value, WeightUnit unit) {
    return unit == WeightUnit.grams ? value / 1000 : value;
  }

  Future<CodChargeResult> calculateCharges({
    required double itemPrice,
    required double weightKg,
    required String senderPostOffice,
    required String receiverPostOffice,
    double? postalChargeOverride,
  }) async {
    final apiUrl = AppConstants.codCalculateApiUrl.trim();

    if (apiUrl.isEmpty) {
      return _fallback(itemPrice, weightKg, postalChargeOverride);
    }

    try {
      final response = await _client.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'itemPrice': itemPrice,
          'weightKg': weightKg,
          'senderPostOffice': senderPostOffice.trim(),
          'receiverPostOffice': receiverPostOffice.trim(),
          if (postalChargeOverride != null)
            'postalChargeOverride': postalChargeOverride,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return CodChargeResult(
        weightCharge: _toDouble(data['weightCharge']),
        postalCharge: _toDouble(data['postalCharge']),
        totalCod: _toDouble(data['totalCod']),
      );
    } catch (e, stack) {
      debugPrint('COD calculation failed: $e\n$stack');
      rethrow; // Let ParcelFormScreen show the error snackbar to the user
    }
  }

  /// Local Sri Lanka Post tier logic used when no API URL is configured.
  CodChargeResult _fallback(
    double itemPrice,
    double weightKg,
    double? postalChargeOverride,
  ) {
    final weightCharge = _weightCharge(weightKg);
    final postalCharge = postalChargeOverride ?? weightCharge;

    return CodChargeResult(
      weightCharge: weightCharge,
      postalCharge: postalCharge,
      totalCod: itemPrice + postalCharge,
    );
  }

  static double _weightCharge(double kg) {
    if (kg <= 0) return 0;
    if (kg <= 0.5) return 150;
    if (kg <= 1.0) return 250;
    return 400;
  }

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}
