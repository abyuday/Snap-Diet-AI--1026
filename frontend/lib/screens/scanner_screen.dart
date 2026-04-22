import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/nutrition_result.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

/// Barcode Scanner screen — three lookup modes:
///   1. 📷 Camera  — take a photo of the barcode
///   2. 🖼️ Gallery — pick an existing image
///   3. ⌨️ Manual  — type the barcode number
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
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────

  Future<void> _captureBarcode(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final result = await ApiService().processBarcodeImage(image);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e.toString().contains('400')
              ? 'No barcode detected.\nTry a clearer, well-lit photo.'
              : 'Failed to process image. Try entering the number manually.';
        });
      }
    }
  }

  Future<void> _lookupBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final result = await ApiService().analyzeBarcode(code);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
      _barcodeController.clear();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e.toString().contains('404')
              ? 'Product not found.\nTry a different barcode or log manually.'
              : 'Error connecting to server. Please try again.';
        });
      }
    }
  }

  // ─────────────────────────────────────
  //  Build
  // ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Barcode Scanner',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Hero icon
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnim.value, child: child),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.85),
                      AppTheme.primaryColor.withOpacity(0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 50),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Scan Food Barcode',
              style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Three ways to look up any packaged food',
              style: TextStyle(color: Colors.white38, fontSize: 13.5),
            ),
            const SizedBox(height: 28),

            // ── Section 1: Image-based scan ──────────────────────────
            _sectionHeader('📷  Scan Barcode via Image'),
            const SizedBox(height: 12),
            _buildImageScanCard(),

            const SizedBox(height: 22),
            _divider(),
            const SizedBox(height: 22),

            // ── Section 2: Manual entry ───────────────────────────────
            _sectionHeader('⌨️  Enter Barcode Manually'),
            const SizedBox(height: 12),
            _buildManualCard(),

            // ── Error banner
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(),
            ],

            const SizedBox(height: 22),

            // ── Info note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Powered by OpenFoodFacts — a free, open database of 3M+ food products worldwide including Indian packaged foods.',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            _buildExamples(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  Image scan card (Camera + Gallery)
  // ─────────────────────────────────────

  Widget _buildImageScanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Point your camera at the barcode on any product,\nor upload a photo from your gallery.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            _loadingIndicator()
          else
            Row(
              children: [
                Expanded(
                  child: _ScanButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppTheme.primaryColor,
                    onTap: () => _captureBarcode(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScanButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _captureBarcode(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          // Tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15)),
            ),
            child: Column(
              children: const [
                _TipRow(Icons.wb_sunny_outlined,
                    'Use good lighting for a clear capture'),
                SizedBox(height: 6),
                _TipRow(Icons.straighten_rounded,
                    'Hold phone ~15–20 cm from barcode'),
                SizedBox(height: 6),
                _TipRow(Icons.crop_rounded,
                    'Make sure the full barcode is in frame'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  Manual entry card
  // ─────────────────────────────────────

  Widget _buildManualCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Barcode Number',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: _barcodeController,
            keyboardType: TextInputType.number,
            onSubmitted: _lookupBarcode,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 3,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '8 901030 870294',
              hintStyle: const TextStyle(
                  color: Colors.white24,
                  fontSize: 17,
                  letterSpacing: 2,
                  fontWeight: FontWeight.normal),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 14),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 20),
              label: Text(
                _isLoading ? 'Looking up…' : 'Look Up Nutrition',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primaryColor.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  Example barcodes
  // ─────────────────────────────────────

  Widget _buildExamples() {
    final examples = [
      {'name': 'Maggi 2-Minute Noodles', 'code': '8901030870294', 'emoji': '🍜'},
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
              color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ...examples.map((e) => GestureDetector(
              onTap: () {
                _barcodeController.text = e['code']!;
                _lookupBarcode(e['code']!);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06)),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(e['code']!,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white24, size: 14),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ─────────────────────────────────────
  //  Small helpers
  // ─────────────────────────────────────

  Widget _sectionHeader(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 0.2)),
      );

  Widget _divider() => Row(children: [
        Expanded(
            child: Container(
                height: 1, color: Colors.white.withOpacity(0.07))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Text('OR',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ),
        Expanded(
            child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.07))),
      ]);

  Widget _loadingIndicator() => Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppTheme.primaryColor),
          ),
        ),
      );

  Widget _buildErrorBanner() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_errorText!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12.5)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────
//  Animated scan button (Camera / Gallery)
// ─────────────────────────────────────────────────────

class _ScanButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ScanButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color,
                widget.color.withOpacity(0.65),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(widget.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Static tip row inside the tips card
// ─────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 12)),
        ),
      ],
    );
  }
}
