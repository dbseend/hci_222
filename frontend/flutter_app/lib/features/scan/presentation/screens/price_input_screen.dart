// price_input_screen.dart
// Purpose: Collects the seller's quoted price + quantity + unit from the user.
//          Calculates the per-unit price (totalPrice / quantity) and forwards
//          it to PriceAnalysisScreen for comparison against the regional average.
// Navigation flow: /scan/stats → /scan/input → /scan/analysis
// Key UX fix: added quantity stepper so users can specify "130 EGP for 2 kg"
//             and get a correct per-unit comparison (65 EGP/kg vs. avg 55 EGP/kg).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/scan_route_data.dart';

class PriceInputScreen extends StatefulWidget {
  final String productName;
  final String productId;

  const PriceInputScreen({
    super.key,
    required this.productName,
    this.productId = 'p001',
  });

  @override
  State<PriceInputScreen> createState() => _PriceInputScreenState();
}

class _PriceInputScreenState extends State<PriceInputScreen> {
  // ── Price input ──────────────────────────────────────────────────
  final _priceController = TextEditingController();
  bool _useSlider = false;

  // Slider range in EGP (Cairo traditional market baseline)
  static const double _sliderMin = 0;
  static const double _sliderMax = 300;
  double _sliderValue = 50;

  // ── Quantity & unit ──────────────────────────────────────────────
  // Supported units. Display label → internal key.
  // Step size: kg uses 0.5 increments; others use 1.
  static const _unitOptions = [
    _UnitOption(key: 'kg', label: 'kg', step: 0.5),
    _UnitOption(key: 'pcs', label: 'pcs', step: 1.0),
    _UnitOption(key: 'bunch', label: 'bunch', step: 1.0),
  ];

  _UnitOption _selectedUnit = _unitOptions[0]; // default: kg
  double _quantity = 1.0; // how many of the selected unit the seller quoted for

  // ── Derived values ───────────────────────────────────────────────
  double get _totalPrice {
    if (_useSlider) return _sliderValue;
    return double.tryParse(_priceController.text) ?? 0;
  }

  /// Price per single unit — this is what gets compared to the regional average.
  double get _perUnitPrice {
    if (_quantity <= 0) return 0;
    return _totalPrice / _quantity;
  }

  bool get _hasInput =>
      _useSlider ? _totalPrice > 0 : _priceController.text.isNotEmpty;

  // ── Quantity helpers ─────────────────────────────────────────────
  void _incrementQuantity() {
    setState(() {
      _quantity = double.parse(
        (_quantity + _selectedUnit.step).toStringAsFixed(1),
      );
    });
  }

  void _decrementQuantity() {
    setState(() {
      final next = _quantity - _selectedUnit.step;
      if (next >= _selectedUnit.step) {
        _quantity = double.parse(next.toStringAsFixed(1));
      }
    });
  }

  String get _quantityLabel {
    // Show as integer when there's no fractional part (e.g. 1.0 → "1")
    return _quantity == _quantity.truncateToDouble()
        ? _quantity.toInt().toString()
        : _quantity.toString();
  }

  // ── Navigation ───────────────────────────────────────────────────
  void _analyze() {
    if (!_hasInput) return;
    // Pass the per-unit price so PriceAnalysisScreen can compare
    // it directly against the regional average (which is also per unit).
    context.go(
      '/scan/analysis',
      extra: ScanRouteData(
        productName: widget.productName.isNotEmpty
            ? widget.productName
            : 'Product',
        productId: widget.productId,
        inputPrice: _perUnitPrice, // EGP per kg / per pc / per bunch
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.productName.isNotEmpty
        ? widget.productName
        : 'Product';
    final displayTotal = _useSlider
        ? _sliderValue.toStringAsFixed(0)
        : (_priceController.text.isNotEmpty ? _priceController.text : '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Price'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scan'),
        ),
        actions: [
          // Toggle between keyboard and slider input
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => setState(() => _useSlider = !_useSlider),
              icon: Icon(
                _useSlider ? Icons.keyboard : Icons.tune,
                size: 18,
                color: AppColors.primary,
              ),
              label: Text(
                _useSlider ? 'Type' : 'Slider',
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "What price is the seller quoting?",
              style: TextStyle(color: AppColors.onSurfaceLight),
            ),
            const SizedBox(height: 24),

            // ── Total price input ──────────────────────────────────
            const Text(
              'Total price quoted',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasInput ? AppColors.primary : Colors.grey.shade300,
                  width: _hasInput ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _useSlider
                        // Slider mode: show read-only value
                        ? Text(
                            displayTotal,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        // Keyboard mode: editable text field
                        : TextField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: AppColors.onSurfaceLight,
                                fontSize: 32,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                  ),
                  const Text(
                    'EGP',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceLight,
                    ),
                  ),
                ],
              ),
            ),

            // Slider (only shown in slider mode)
            if (_useSlider) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _sliderMin.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceLight,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _sliderValue,
                      min: _sliderMin,
                      max: _sliderMax,
                      divisions: 60, // 5 EGP steps
                      activeColor: AppColors.primary,
                      label: '${_sliderValue.toStringAsFixed(0)} EGP',
                      onChanged: (v) => setState(() => _sliderValue = v),
                    ),
                  ),
                  Text(
                    _sliderMax.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceLight,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Quantity + unit ────────────────────────────────────
            const Text(
              'For how much?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Quantity stepper
                _QuantityStepper(
                  value: _quantityLabel,
                  onDecrement: _decrementQuantity,
                  onIncrement: _incrementQuantity,
                  canDecrement: _quantity > _selectedUnit.step,
                ),
                const SizedBox(width: 16),
                // Unit chips
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _unitOptions.map((u) {
                      final selected = _selectedUnit.key == u.key;
                      return ChoiceChip(
                        label: Text(u.label),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _selectedUnit = u;
                          // Reset quantity to the new unit's minimum step
                          _quantity = u.step;
                        }),
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Per-unit price (derived) ───────────────────────────
            // This is the value that will be compared to the regional average.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _hasInput
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasInput
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    size: 18,
                    color: AppColors.onSurfaceLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Per ${_selectedUnit.label}:  ',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceLight,
                    ),
                  ),
                  Text(
                    _hasInput && _quantity > 0
                        ? '${_perUnitPrice.toStringAsFixed(1)} EGP'
                        : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _hasInput
                          ? AppColors.primary
                          : AppColors.onSurfaceLight,
                    ),
                  ),
                  if (_quantity > _selectedUnit.step) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($displayTotal EGP ÷ $_quantityLabel ${_selectedUnit.label})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _hasInput ? _analyze : null,
              child: const Text('Analyze Price'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

/// Increment / decrement stepper for quantity.
class _QuantityStepper extends StatelessWidget {
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool canDecrement;

  const _QuantityStepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.canDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: canDecrement ? onDecrement : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _StepButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
    );
  }
}

/// Descriptor for each unit type (display label + stepper increment size).
class _UnitOption {
  final String key;
  final String label;
  final double step;

  const _UnitOption({
    required this.key,
    required this.label,
    required this.step,
  });
}
