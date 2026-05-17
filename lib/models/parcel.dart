import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

enum ParcelStatus {
  registered('registered'),
  redirected('redirected'),
  delivered('delivered');

  const ParcelStatus(this.value);
  final String value;

  static ParcelStatus fromString(String? raw) {
    return ParcelStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => ParcelStatus.registered,
    );
  }
}

/// Domain model for a registered parcel stored in Firestore.
class Parcel {
  const Parcel({
    required this.trackingId,
    required this.senderName,
    required this.senderPhone,
    required this.senderPostOffice,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverPostOffice,
    required this.receiverAddress,
    required this.description,
    required this.itemPrice,
    required this.weightKg,
    required this.weightCharge,
    required this.postalCharge,
    required this.totalCod,
    this.status = ParcelStatus.registered,
    this.createdAt,
    this.deliveredAt,
    this.sentFromPostOffice,
    this.redirectToPostOffice,
    this.redirectReason,
    this.redirectedAt,
  });

  final String trackingId;
  final String senderName;
  final String senderPhone;
  final String senderPostOffice;
  final String receiverName;
  final String receiverPhone;
  final String receiverPostOffice;
  final String receiverAddress;
  final String description;
  final double itemPrice;
  final double weightKg;
  final double weightCharge;
  final double postalCharge;
  final double totalCod;
  final ParcelStatus status;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final String? sentFromPostOffice;
  final String? redirectToPostOffice;
  final String? redirectReason;
  final DateTime? redirectedAt;

  bool get isDelivered => status == ParcelStatus.delivered;
  bool get isRedirected => status == ParcelStatus.redirected;

  String get statusLabel {
    if (isDelivered) return 'Delivered';
    if (isRedirected) return 'Redirected';
    return 'Pending delivery';
  }

  String get trackingUrl => AppConstants.trackingUrl(trackingId);

  Map<String, dynamic> toMap() {
    return {
      'trackingId': trackingId,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'senderPostOffice': senderPostOffice,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'receiverPostOffice': receiverPostOffice,
      'receiverAddress': receiverAddress,
      'description': description,
      'itemPrice': itemPrice,
      'weightKg': weightKg,
      'weightCharge': weightCharge,
      'postalCharge': postalCharge,
      'totalCod': totalCod,
      'status': status.value,
      'createdAt': FieldValue.serverTimestamp(),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (sentFromPostOffice != null) 'sentFromPostOffice': sentFromPostOffice,
      if (redirectToPostOffice != null)
        'redirectToPostOffice': redirectToPostOffice,
      if (redirectReason != null) 'redirectReason': redirectReason,
      if (redirectedAt != null)
        'redirectedAt': Timestamp.fromDate(redirectedAt!),
    };
  }

  factory Parcel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Parcel(
      trackingId: data['trackingId'] as String? ?? doc.id,
      senderName: data['senderName'] as String? ?? '',
      senderPhone: data['senderPhone'] as String? ?? '',
      senderPostOffice: data['senderPostOffice'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? '',
      receiverPhone: data['receiverPhone'] as String? ?? '',
      receiverPostOffice: data['receiverPostOffice'] as String? ?? '',
      receiverAddress: data['receiverAddress'] as String? ?? '',
      description: data['description'] as String? ?? '',
      itemPrice: _toDouble(data['itemPrice']),
      weightKg: _toDouble(data['weightKg']),
      weightCharge: _toDouble(data['weightCharge']),
      postalCharge: _toDouble(data['postalCharge']),
      totalCod: _toDouble(data['totalCod']),
      status: ParcelStatus.fromString(data['status'] as String?),
      createdAt: _toDateTime(data['createdAt']),
      deliveredAt: _toDateTime(data['deliveredAt']),
      sentFromPostOffice: data['sentFromPostOffice'] as String?,
      redirectToPostOffice: data['redirectToPostOffice'] as String?,
      redirectReason: data['redirectReason'] as String?,
      redirectedAt: _toDateTime(data['redirectedAt']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
