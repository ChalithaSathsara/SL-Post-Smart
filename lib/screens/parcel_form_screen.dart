import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/parcel.dart';
import '../services/cod_charge_service.dart';
import '../services/firestore_service.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/sl_top_bar.dart';
import 'scanner_screen.dart';
import 'tracking_screen.dart';

/// Register parcel with COD fields; charges calculated via [CodChargeService].
class ParcelFormScreen extends StatefulWidget {
  const ParcelFormScreen({super.key});

  @override
  State<ParcelFormScreen> createState() => _ParcelFormScreenState();
}

class _ParcelFormScreenState extends State<ParcelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _smsService = SmsService();
  final _codChargeService = CodChargeService();

  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();
  final _senderPostOffice = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverPostOffice = TextEditingController();
  final _receiverAddress = TextEditingController();
  final _description = TextEditingController();
  final _itemPrice = TextEditingController();
  final _weight = TextEditingController();
  final _postalCharge = TextEditingController();

  WeightUnit _weightUnit = WeightUnit.kilograms;
  bool _postalChargeOverridden = false;
  bool _isProgrammaticPostalUpdate = false;
  bool _isSubmitting = false;
  bool _isCalculating = false;

  double _weightCharge = 0;
  double _totalCod = 0;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _itemPrice.addListener(_scheduleCalc);
    _weight.addListener(_scheduleCalc);
    _senderPostOffice.addListener(_scheduleCalc);
    _receiverPostOffice.addListener(_scheduleCalc);
    _postalCharge.addListener(_onPostalChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _senderName.dispose();
    _senderPhone.dispose();
    _senderPostOffice.dispose();
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverPostOffice.dispose();
    _receiverAddress.dispose();
    _description.dispose();
    _itemPrice.dispose();
    _weight.dispose();
    _postalCharge.dispose();
    super.dispose();
  }

  // ---------------- HELPERS ----------------

  double _num(String v) {
    final parsed = double.tryParse(v.trim());
    return (parsed == null || parsed < 0) ? 0 : parsed;
  }

  double get _weightKg =>
      CodChargeService.normalizeWeightToKg(_num(_weight.text), _weightUnit);

  bool get _hasValidWeight => _num(_weight.text) > 0;

  bool get _canSubmit =>
      _hasValidWeight &&
      _num(_itemPrice.text) > 0 &&
      _senderPostOffice.text.trim().isNotEmpty &&
      _receiverPostOffice.text.trim().isNotEmpty &&
      _totalCod > 0;

  // ---------------- DEBOUNCE ----------------

  void _scheduleCalc() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _calculateCOD);
  }

  void _onPostalChanged() {
    if (_isProgrammaticPostalUpdate) return;
    setState(() => _postalChargeOverridden = true);
    _scheduleCalc();
  }

  // ---------------- COD CALCULATION ----------------

  Future<void> _calculateCOD() async {
    if (!_hasValidWeight) {
      setState(() {
        _weightCharge = 0;
        _totalCod = 0;
      });
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final result = await _codChargeService.calculateCharges(
        itemPrice: _num(_itemPrice.text),
        weightKg: _weightKg,
        senderPostOffice: _senderPostOffice.text.trim(),
        receiverPostOffice: _receiverPostOffice.text.trim(),
        postalChargeOverride: _postalChargeOverridden
            ? _num(_postalCharge.text)
            : null,
      );

      if (!mounted) return;

      if (!_postalChargeOverridden) {
        _isProgrammaticPostalUpdate = true;
        _postalCharge.text = result.postalCharge.toStringAsFixed(0);
        _isProgrammaticPostalUpdate = false;
      }

      setState(() {
        _weightCharge = result.weightCharge;
        _totalCod = result.totalCod;
        _isCalculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCalculating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('COD error: $e')));
    }
  }

  void _resetPostal() {
    setState(() => _postalChargeOverridden = false);
    _calculateCOD();
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields and wait for COD total')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final trackingId = AppConstants.generateTrackingId();

    final parcel = Parcel(
      trackingId: trackingId,
      senderName: _senderName.text.trim(),
      senderPhone: _senderPhone.text.trim(),
      senderPostOffice: _senderPostOffice.text.trim(),
      receiverName: _receiverName.text.trim(),
      receiverPhone: _receiverPhone.text.trim(),
      receiverPostOffice: _receiverPostOffice.text.trim(),
      receiverAddress: _receiverAddress.text.trim(),
      description: _description.text.trim(),
      itemPrice: _num(_itemPrice.text),
      weightKg: _weightKg,
      weightCharge: _weightCharge,
      postalCharge: _num(_postalCharge.text),
      totalCod: _totalCod,
    );

    try {
      await _firestoreService.saveParcel(parcel);

      final sms = await _smsService.sendParcelRegisteredSms(
        senderPhone: parcel.senderPhone,
        receiverPhone: parcel.receiverPhone,
        trackingId: parcel.trackingId,
        registeredBranchName: parcel.senderPostOffice,
      );

      if (!mounted) return;

      if (!sms.success && sms.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcel saved. SMS issue: ${sms.message}'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      } else if (sms.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS sent to sender and receiver')),
        );
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrackingScreen(parcel: parcel, smsSent: sms.success),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------- VALIDATORS ----------------

  String? _req(String? v, String f) =>
      (v == null || v.trim().isEmpty) ? 'Enter $f' : null;

  String? _phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter phone number';
    if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Invalid phone number';
    }
    return null;
  }

  String? _numVal(String? v, String f) {
    if (v == null || v.trim().isEmpty) return 'Enter $f';
    if (double.tryParse(v.trim()) == null) return 'Enter valid $f';
    return null;
  }

  String? _positiveNum(String? v, String f) {
    final base = _numVal(v, f);
    if (base != null) return base;
    if (_num(v!) <= 0) return '$f must be greater than 0';
    return null;
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SlTopBar(
        title: 'New Parcel',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Sender Details',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  TextFormField(
                    controller: _senderName,
                    decoration: const InputDecoration(
                      labelText: 'Sender Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _req(v, 'sender name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senderPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Sender Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: _phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senderPostOffice,
                    decoration: const InputDecoration(
                      labelText: 'Sender Post Office',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _req(v, 'sender post office'),
                  ),
                ],
              ),
            ),

            SectionCard(
              title: 'Receiver Details',
              icon: Icons.person_pin_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _receiverName,
                    decoration: const InputDecoration(
                      labelText: 'Receiver Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _req(v, 'receiver name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiverPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Receiver Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: _phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiverPostOffice,
                    decoration: const InputDecoration(
                      labelText: 'Receiver Post Office',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _req(v, 'receiver post office'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiverAddress,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Receiver Address',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _req(v, 'receiver address'),
                  ),
                ],
              ),
            ),

            SectionCard(
              title: 'Parcel & COD',
              icon: Icons.inventory_2_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Parcel Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _req(v, 'parcel description'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _itemPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Item Price (Rs.)',
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _positiveNum(v, 'item price'),
                    onChanged: (_) => _scheduleCalc(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Weight (${_weightUnit.label})',
                            border: const OutlineInputBorder(),
                            helperText: _weightKg > 0
                                ? '${_weightKg.toStringAsFixed(3)} kg'
                                : null,
                          ),
                          validator: (v) => _positiveNum(v, 'weight'),
                          onChanged: (_) => _scheduleCalc(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<WeightUnit>(
                          value: _weightUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: WeightUnit.values
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.label),
                                ),
                              )
                              .toList(),
                          onChanged: (unit) {
                            if (unit == null) {
                              return;
                            }
                            setState(() => _weightUnit = unit);
                            _scheduleCalc();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _postalCharge,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Postal Charge (Rs.)',
                      prefixText: 'Rs. ',
                      border: const OutlineInputBorder(),
                      helperText: _postalChargeOverridden
                          ? 'Manual override'
                          : 'Auto from weight',
                      suffixIcon: _postalChargeOverridden
                          ? IconButton(
                              tooltip: 'Reset to auto rate',
                              icon: const Icon(Icons.refresh),
                              onPressed: _resetPostal,
                            )
                          : null,
                    ),
                    validator: (v) => _numVal(v, 'postal charge'),
                  ),
                ],
              ),
            ),

            // COD Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'COD Summary',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isCalculating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Weight charge',
                    value: 'Rs. ${_weightCharge.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Postal charge',
                    value: 'Rs. ${_num(_postalCharge.text).toStringAsFixed(0)}',
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Total COD',
                    value: 'Rs. ${_totalCod.toStringAsFixed(0)}',
                    emphasized: true,
                  ),
                  if (!_hasValidWeight)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Enter weight to calculate charges',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            PrimaryButton(
              label: 'Generate Tracking Number',
              icon: Icons.qr_code_2,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: emphasized
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: emphasized
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                )
              : theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}
