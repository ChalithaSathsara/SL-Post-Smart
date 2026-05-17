import 'package:flutter/material.dart';

import '../models/parcel.dart';
import '../services/firestore_service.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sl_green_button.dart';
import '../widgets/sl_top_bar.dart';

/// Postman view: parcel details after QR scan, COD collection, mark delivered.
class ParcelDetailsScreen extends StatefulWidget {
  const ParcelDetailsScreen({super.key, required this.trackingId});

  final String trackingId;

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen> {
  final _firestoreService = FirestoreService();
  final _smsService = SmsService();

  Parcel? _parcel;
  bool _loading = true;
  bool _completing = false;
  bool _redirecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParcel();
  }

  Future<void> _loadParcel() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parcel = await _firestoreService.getParcelByTrackingId(
        widget.trackingId,
      );
      if (!mounted) return;
      setState(() {
        _parcel = parcel;
        _loading = false;
        if (parcel == null) {
          _error = 'No parcel found for ID: ${widget.trackingId}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load parcel: $e';
      });
    }
  }

  Future<void> _confirmDeliveryComplete() async {
    final parcel = _parcel;
    if (parcel == null || parcel.isDelivered) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm delivery'),
        content: Text(
          'Confirm you collected Rs. ${parcel.totalCod.toStringAsFixed(0)} COD '
          'from ${parcel.receiverName}?\n\n'
          'SMS will be sent to sender and receiver.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delivery complete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _completeDelivery();
  }

  Future<void> _showRedirectForm() async {
    final parcel = _parcel;
    if (parcel == null || parcel.isDelivered) return;

    final result = await showModalBottomSheet<_RedirectFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _RedirectParcelSheet(initialSentFrom: parcel.sentFromPostOffice),
    );

    if (result == null || !mounted) return;
    await _submitRedirect(result);
  }

  Future<void> _submitRedirect(_RedirectFormResult form) async {
    final parcel = _parcel;
    if (parcel == null) return;

    setState(() => _redirecting = true);

    try {
      await _firestoreService.redirectParcel(
        trackingId: parcel.trackingId,
        sentFromPostOffice: form.sentFromPostOffice,
        redirectToPostOffice: form.redirectToPostOffice,
        redirectReason: form.redirectReason,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parcel redirected to ${form.redirectToPostOffice}'),
        ),
      );
      await _loadParcel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to redirect: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _redirecting = false);
    }
  }

  Future<void> _completeDelivery() async {
    final parcel = _parcel;
    if (parcel == null) return;

    setState(() => _completing = true);

    try {
      await _firestoreService.markParcelAsDelivered(parcel.trackingId);

      final smsResult = await _smsService.sendDeliveryCompletedSms(
        senderPhone: parcel.senderPhone,
        receiverPhone: parcel.receiverPhone,
        trackingId: parcel.trackingId,
        totalCod: parcel.totalCod,
        deliveredPostOfficeName: parcel.sentFromPostOffice ?? 'Sri Lanka Post',
      );

      if (!mounted) return;

      if (!smsResult.success && smsResult.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery saved. SMS issue: ${smsResult.message}'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      } else if (smsResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Delivery complete. SMS sent to sender and receiver.',
            ),
          ),
        );
      }

      await _loadParcel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete delivery: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SlTopBar(title: 'Delivery Confirmation'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadParcel, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final parcel = _parcel!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (parcel.isDelivered)
          Card(
            color: AppColors.successLight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivered',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        if (parcel.deliveredAt != null)
                          Text(
                            parcel.deliveredAt!.toLocal().toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (parcel.isRedirected)
            Card(
              color: AppColors.warningLight,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alt_route, color: AppColors.warning),
                        const SizedBox(width: 12),
                        const Text(
                          'Redirected to correct office',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DetailRow('From office', parcel.sentFromPostOffice ?? '—'),
                    _DetailRow('To office', parcel.redirectToPostOffice ?? '—'),
                    _DetailRow('Reason', parcel.redirectReason ?? '—'),
                    if (parcel.redirectedAt != null)
                      _DetailRow(
                        'Redirected at',
                        parcel.redirectedAt!.toLocal().toString(),
                      ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Collect COD from receiver',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${parcel.totalCod.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(parcel.receiverName, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _DetailCard(
          title: 'Tracking',
          children: [
            _DetailRow('Tracking ID', parcel.trackingId),
            _DetailRow('Status', parcel.statusLabel),
          ],
        ),
        _DetailCard(
          title: 'Sender',
          children: [
            _DetailRow('Name', parcel.senderName),
            _DetailRow('Phone', parcel.senderPhone),
            _DetailRow('Post office', parcel.senderPostOffice),
          ],
        ),
        _DetailCard(
          title: 'Receiver',
          children: [
            _DetailRow('Name', parcel.receiverName),
            _DetailRow('Phone', parcel.receiverPhone),
            _DetailRow('Post office', parcel.receiverPostOffice),
            _DetailRow('Address', parcel.receiverAddress),
          ],
        ),
        _DetailCard(
          title: 'Parcel & COD',
          children: [
            _DetailRow('Description', parcel.description),
            _DetailRow(
              'Item price',
              'Rs. ${parcel.itemPrice.toStringAsFixed(0)}',
            ),
            _DetailRow('Weight', '${parcel.weightKg.toStringAsFixed(3)} kg'),
            _DetailRow(
              'Postal charge',
              'Rs. ${parcel.postalCharge.toStringAsFixed(0)}',
            ),
            _DetailRow(
              'Total COD',
              'Rs. ${parcel.totalCod.toStringAsFixed(0)}',
              emphasized: true,
            ),
          ],
        ),
        if (!parcel.isDelivered) ...[
          const SizedBox(height: 8),
          SlGreenButton(
            label: 'Confirm Delivery',
            icon: Icons.check_circle_outline,
            isLoading: _completing,
            onPressed: (_completing || _redirecting)
                ? null
                : _confirmDeliveryComplete,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: (_completing || _redirecting)
                  ? null
                  : _showRedirectForm,
              icon: _redirecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.alt_route),
              label: Text(
                parcel.isRedirected ? 'Update redirect' : 'Redirect parcel',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan another parcel'),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan another parcel'),
            ),
          ),
      ],
    );
  }
}

class _RedirectFormResult {
  const _RedirectFormResult({
    required this.sentFromPostOffice,
    required this.redirectToPostOffice,
    required this.redirectReason,
  });

  final String sentFromPostOffice;
  final String redirectToPostOffice;
  final String redirectReason;
}

class _RedirectParcelSheet extends StatefulWidget {
  const _RedirectParcelSheet({this.initialSentFrom});

  final String? initialSentFrom;

  @override
  State<_RedirectParcelSheet> createState() => _RedirectParcelSheetState();
}

class _RedirectParcelSheetState extends State<_RedirectParcelSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _sentFromController = TextEditingController(
    text: widget.initialSentFrom ?? '',
  );
  final _redirectToController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _sentFromController.dispose();
    _redirectToController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _RedirectFormResult(
        sentFromPostOffice: _sentFromController.text.trim(),
        redirectToPostOffice: _redirectToController.text.trim(),
        redirectReason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Redirect Parcel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Parcel arrived at the wrong delivery point. Send it to the correct office.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _sentFromController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Send post office',
                hintText: 'Current / wrong office name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.outbound_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _redirectToController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Redirect post office',
                hintText: 'Correct delivery office name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.markunread_mailbox_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why this parcel is being redirected',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submit,
              icon: const Icon(Icons.alt_route),
              label: const Text('Redirect Parcel'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: emphasized
                  ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    )
                  : Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
