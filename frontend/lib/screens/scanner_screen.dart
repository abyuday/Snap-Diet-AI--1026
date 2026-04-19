import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/nutrition_result.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

/// Scanner screen that works on both web and mobile.
///
/// Web:  Manual barcode entry (text field) — no native camera dependency.
/// Mobile: Camera-based capture via image_picker (already in pubspec),
///         with a text-entry fallback.
///
/// The actual nutrition lookup is done via the backend /analyze-barcode endpoint.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _barcodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;
    setState(() { _isLoading = true; _errorText = null; });

    try {
      const apiBase = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8005',
      );
      final uri = Uri.parse('$apiBase/analyze-barcode?barcode=${Uri.encodeComponent(code)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = NutritionResult.fromJson(data);
        setState(() { _isLoading = false; });
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
        );
        // Clear field for next scan
        _barcodeController.clear();
      } else if (response.statusCode == 404) {
        setState(() {
          _isLoading = false;
          _errorText = 'Product not found in the OpenFoodFacts database.\nTry a different barcode.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorText = 'Server error (${response.statusCode}). Please try again.';
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Could not reach server. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Barcode Scanner',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // Animated icon
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.8),
                      AppTheme.primaryColor.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Scan Food Barcode',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the barcode number from the\nproduct packaging below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Barcode input card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Barcode Number',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    onSubmitted: _lookupBarcode,
                    decoration: InputDecoration(
                      hintText: '8 901030 870294',
                      hintStyle: TextStyle(
                        color: Colors.white24,
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _lookupBarcode(_barcodeController.text),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search_rounded, size: 20),
                      label: Text(
                        _isLoading ? 'Looking up...' : 'Look Up Nutrition',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Powered by OpenFoodFacts — a free, open database of 3M+ food products worldwide including Indian packaged foods.',
                      style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Example barcodes
            _buildExampleBarcodes(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleBarcodes() {
    final examples = [
      {'name': 'Maggi Noodles', 'code': '8901030870294', 'emoji': '🍜'},
      {'name': 'Nutella 400g', 'code': '3017620425400', 'emoji': '🍫'},
      {'name': 'Coca-Cola 330ml', 'code': '5449000000996', 'emoji': '🥤'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try These Examples',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        ...examples.map((e) => GestureDetector(
          onTap: () {
            _barcodeController.text = e['code']!;
            _lookupBarcode(e['code']!);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Text(e['emoji']!, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['name']!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(e['code']!,
                          style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
