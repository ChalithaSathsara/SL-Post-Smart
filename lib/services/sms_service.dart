import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sends SMS via Notify.lk API.
/// Works on Android, iOS, and all platforms — no SIM or permissions needed.
class SmsService {
  static const String _userId = '31782';
  static const String _apiKey =
      'MosklNsxFvkiL4zARag4'; // ← update after resetting
  static const String _senderId =
      'NotifyDEMO'; // ← change to your Sender ID when approved
  static const String _baseUrl = 'https://app.notify.lk/api/v1/send';
  static const String _trackingBaseUrl = 'https://bepost.lk/newsoap/';

  Future<SmsResult> sendParcelRegisteredSms({
    required String senderPhone,
    required String receiverPhone,
    required String trackingId,
    required String registeredBranchName,
  }) async {
    return _sendDualSms(
      senderPhone: senderPhone,
      receiverPhone: receiverPhone,
      senderMessage:
          'Sri Lanka Post: Your COD parcel has been successfully registered. '
          'Branch: $registeredBranchName. '
          'Tracking No: $trackingId. '
          'Track: $_trackingBaseUrl$trackingId',
      receiverMessage:
          'Sri Lanka Post: A parcel has been registered for delivery to you. '
          'Branch: $registeredBranchName. '
          'Tracking No: $trackingId. '
          'Track: $_trackingBaseUrl$trackingId',
    );
  }

  Future<SmsResult> sendParcelRedirectedSms({
    required String senderPhone,
    required String receiverPhone,
    required String trackingId,
    required String targetOfficeName,
  }) async {
    return _sendDualSms(
      senderPhone: senderPhone,
      receiverPhone: receiverPhone,
      senderMessage:
          'Sri Lanka Post: Your COD parcel ($trackingId) has been redirected '
          'to the correct delivery office: $targetOfficeName. '
          'Track: $_trackingBaseUrl$trackingId',
      receiverMessage:
          'Sri Lanka Post: Your parcel ($trackingId) was sorted incorrectly '
          'and is now being rerouted to $targetOfficeName Post Office for local delivery. '
          'Track: $_trackingBaseUrl$trackingId',
    );
  }

  Future<SmsResult> sendDeliveryCompletedSms({
    required String senderPhone,
    required String receiverPhone,
    required String trackingId,
    required double totalCod,
    required String deliveredPostOfficeName,
  }) async {
    final codText = totalCod.toStringAsFixed(0);

    return _sendDualSms(
      senderPhone: senderPhone,
      receiverPhone: receiverPhone,
      senderMessage:
          'Sri Lanka Post: Your parcel has been successfully delivered. '
          'Tracking No: $trackingId. '
          'COD amount of Rs. $codText has been collected. '
          'Delivering office: $deliveredPostOfficeName.',
      receiverMessage:
          'Sri Lanka Post: Your parcel has been successfully delivered. '
          'Tracking No: $trackingId. '
          'COD amount of Rs. $codText has been paid. '
          'Delivered by: $deliveredPostOfficeName Post Office. '
          'Thank you for using Sri Lanka Post.',
    );
  }

  Future<SmsResult> _sendDualSms({
    required String senderPhone,
    required String receiverPhone,
    required String senderMessage,
    required String receiverMessage,
  }) async {
    try {
      final sPhone = _normalizeSriLanka(senderPhone);
      final rPhone = _normalizeSriLanka(receiverPhone);

      debugPrint('Notify.lk SMS -> Sender: $sPhone');
      debugPrint('Notify.lk SMS -> Receiver: $rPhone');

      // Send to sender
      final senderSent = await _sendWithRetry(sPhone, senderMessage);
      if (!senderSent) {
        debugPrint('SMS WARNING: Failed to send to sender after retries');
      }

      // Delay between messages to avoid rate limiting
      await Future.delayed(const Duration(seconds: 1));

      // Send to receiver
      final receiverSent = await _sendWithRetry(rPhone, receiverMessage);
      if (!receiverSent) {
        debugPrint('SMS WARNING: Failed to send to receiver after retries');
      }

      if (senderSent && receiverSent) {
        debugPrint('SMS sent successfully to both parties');
        return SmsResult.success();
      } else if (senderSent || receiverSent) {
        return SmsResult.failure('SMS sent to one party only');
      } else {
        return SmsResult.failure('SMS failed for both parties');
      }
    } catch (e, stack) {
      debugPrint('SMS ERROR: $e\n$stack');
      return SmsResult.failure('SMS failed: $e');
    }
  }

  Future<bool> _sendWithRetry(
    String phone,
    String message, {
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('SMS attempt $attempt/$maxAttempts -> $phone');

        final uri = Uri.parse(_baseUrl).replace(
          queryParameters: {
            'user_id': _userId,
            'api_key': _apiKey,
            'sender_id': _senderId,
            'to': phone,
            'message': message,
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));

        debugPrint(
          'Notify.lk response [${response.statusCode}]: ${response.body}',
        );

        if (response.statusCode == 200) {
          if (response.body.contains('"success"')) {
            debugPrint('SMS attempt $attempt succeeded -> $phone');
            return true;
          } else {
            debugPrint('SMS attempt $attempt rejected -> ${response.body}');
          }
        }
      } catch (e) {
        debugPrint('SMS attempt $attempt failed -> $phone: $e');
      }

      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return false;
  }

  String _normalizeSriLanka(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.startsWith('0')) {
      cleaned = '94${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('94')) {
      cleaned = '94$cleaned';
    }

    return cleaned;
  }
}

class SmsResult {
  const SmsResult._({required this.success, this.message});

  final bool success;
  final String? message;

  factory SmsResult.success() => const SmsResult._(success: true);

  factory SmsResult.failure(String msg) =>
      SmsResult._(success: false, message: msg);

  factory SmsResult.skipped(String msg) =>
      SmsResult._(success: false, message: msg);
}
