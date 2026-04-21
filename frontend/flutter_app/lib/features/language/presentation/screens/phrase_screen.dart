// phrase_screen.dart
// Displays a categorized list of Arabic phrases useful for market shopping.
// Phrases are loaded from assets/data/phrases.json and shown with Arabic text,
// romanized pronunciation, and an English label. Each card has a TTS button
// that speaks the Arabic phrase aloud via TtsService.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/widgets/app_card.dart';

class PhraseScreen extends StatefulWidget {
  const PhraseScreen({super.key});

  @override
  State<PhraseScreen> createState() => _PhraseScreenState();
}

class _PhraseScreenState extends State<PhraseScreen> {
  List<Map<String, dynamic>> _phrases = [];
  String _selectedCategory = 'all';

  static const _categories = [
    ('all', 'All'),
    ('greeting', 'Greeting'),
    ('price_ask', 'Ask Price'),
    ('too_expensive', 'Negotiate'),
    ('discount', 'Discount'),
    ('buy', 'Purchase'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPhrases();
  }

  Future<void> _loadPhrases() async {
    final json = await rootBundle.loadString('assets/data/phrases.json');
    final list = jsonDecode(json) as List;
    setState(() {
      _phrases = list.cast<Map<String, dynamic>>();
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'all') return _phrases;
    return _phrases.where((p) => p['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arabic Phrases')),
      body: Column(
        children: [
          _CategoryChips(),
          Expanded(
            child: _phrases.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _PhraseCard(phrase: _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _CategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _categories.map((c) {
          final selected = _selectedCategory == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(c.$2),
              selected: selected,
              onSelected: (_) => setState(() => _selectedCategory = c.$1),
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.onSurfaceLight,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PhraseCard extends StatefulWidget {
  final Map<String, dynamic> phrase;
  const _PhraseCard({required this.phrase});

  @override
  State<_PhraseCard> createState() => _PhraseCardState();
}

class _PhraseCardState extends State<_PhraseCard> {
  bool _speaking = false;
  final _tts = TtsService();

  Future<void> _speak() async {
    final text = widget.phrase['text_ar'] as String? ?? '';
    if (text.isEmpty) return;
    setState(() => _speaking = true);
    await _tts.speakArabic(text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.phrase['text_kr'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _speaking ? Icons.stop_circle : Icons.volume_up,
                    color: _speaking ? AppColors.warning : AppColors.primary,
                  ),
                  onPressed: _speaking ? _tts.stop : _speak,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.phrase['text_ar'] ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontFamily: 'NotoSansArabic',
                color: AppColors.onSurface,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 4),
            Text(
              widget.phrase['romanized'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
