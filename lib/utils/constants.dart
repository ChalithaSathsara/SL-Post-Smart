/// App-wide constants for tracking URLs and collection names.
class AppConstants {
  AppConstants._();

  /// Base URL shown in SMS and on tracking screen (prototype domain).
  static const String trackingBaseUrl = 'https://yourapp.com/track';

  /// Firestore collection name for parcel documents.
  static const String parcelsCollection = 'parcels';

  /// POST endpoint for COD calculation. Leave empty to use built-in fallback tiers.
  static const String codCalculateApiUrl = '';

  /// Sri Lanka postal codes are 5 digits.
  static const int postalCodeLength = 5;

  /// Builds full tracking URL for a given tracking ID.
  static String trackingUrl(String trackingId) =>
      '$trackingBaseUrl/$trackingId';

  /// Generates unique tracking ID: TRK + millisecond timestamp.
  static String generateTrackingId() {
    return 'TRK${DateTime.now().millisecondsSinceEpoch}';
  }
}
