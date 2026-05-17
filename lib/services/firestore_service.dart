import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parcel.dart';
import '../utils/constants.dart';

/// Handles all Firestore read/write operations for parcels.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _parcels =>
      _firestore.collection(AppConstants.parcelsCollection);

  /// Saves parcel using [trackingId] as document ID.
  Future<void> saveParcel(Parcel parcel) async {
    await _parcels.doc(parcel.trackingId.trim()).set(parcel.toMap());
  }

  /// Redirects parcel to the correct post office.
  Future<void> redirectParcel({
    required String trackingId,
    required String sentFromPostOffice,
    required String redirectToPostOffice,
    required String redirectReason,
  }) async {
    await _parcels.doc(trackingId.trim()).update({
      'status': ParcelStatus.redirected.value,
      'sentFromPostOffice': sentFromPostOffice.trim(),
      'redirectToPostOffice': redirectToPostOffice.trim(),
      'redirectReason': redirectReason.trim(),
      'redirectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks parcel as delivered (postman completed COD collection).
  Future<void> markParcelAsDelivered(String trackingId) async {
    await _parcels.doc(trackingId.trim()).update({
      'status': ParcelStatus.delivered.value,
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches a single parcel by tracking ID. Returns null if not found.
  Future<Parcel?> getParcelByTrackingId(String trackingId) async {
    final doc = await _parcels
        .doc(trackingId.trim())
        .get()
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Request timed out. Check your connection.'),
        );

    if (!doc.exists || doc.data() == null) return null;
    return Parcel.fromFirestore(doc);
  }
}
