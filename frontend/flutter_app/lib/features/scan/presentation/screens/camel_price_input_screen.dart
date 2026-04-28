import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/scan_route_data.dart';

class CamelPriceInputScreen extends StatefulWidget {
  const CamelPriceInputScreen({super.key});

  @override
  State<CamelPriceInputScreen> createState() => _CamelPriceInputScreenState();
}

class _CamelPriceInputScreenState extends State<CamelPriceInputScreen> {
  final _minutesController = TextEditingController();
  final _priceController = TextEditingController();

  double get _minutes => double.tryParse(_minutesController.text) ?? 0;
  double get _totalPrice => double.tryParse(_priceController.text) ?? 0;
  double get _pricePerMinute => _minutes <= 0 ? 0 : _totalPrice / _minutes;
  bool get _canAnalyze => _minutes > 0 && _totalPrice > 0;

  void _analyze() {
    if (!_canAnalyze) return;

    context.go(
      '/scan/analysis',
      extra: ScanRouteData(
        productName: 'Camel ride (${_minutes.toStringAsFixed(0)} min)',
        productId: 'camel_ride',
        inputPrice: _pricePerMinute,
      ),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hiking, color: AppColors.primary, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Camel ride price check',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Enter the offered duration and total price. We compare the price per minute.',
                    style: TextStyle(
                      color: AppColors.onSurfaceLight,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _NumberField(
              controller: _minutesController,
              label: 'Ride duration',
              suffix: 'min',
              hint: '30',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            _NumberField(
              controller: _priceController,
              label: 'Offered total price',
              suffix: 'EGP',
              hint: '300',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    color: AppColors.onSurfaceLight,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Price per minute',
                    style: TextStyle(color: AppColors.onSurfaceLight),
                  ),
                  const Spacer(),
                  Text(
                    _canAnalyze
                        ? '${_pricePerMinute.toStringAsFixed(1)} EGP'
                        : '-',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _canAnalyze
                          ? AppColors.primary
                          : AppColors.onSurfaceLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _canAnalyze ? _analyze : null,
              child: const Text('Analyze Camel Ride Price'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final String hint;
  final VoidCallback onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.onSurfaceLight),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              Text(
                suffix,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
