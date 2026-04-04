import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/nutrition_result.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class AnalysisScreen extends StatefulWidget {
  /// Legacy single-image support
  final XFile? imageFile;

  /// Multi-image support (preferred)
  final List<XFile>? imageFiles;

  const AnalysisScreen({super.key, this.imageFile, this.imageFiles})
      : assert(imageFile != null || imageFiles != null,
            'Either imageFile or imageFiles must be provided');

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _hasError = false;
  String? _errorMessage;

  /// All images being analyzed
  late final List<XFile> _allImages;
  final Map<int, Uint8List> _thumbs = {};

  @override
  void initState() {
    super.initState();

    // Consolidate images
    if (widget.imageFiles != null && widget.imageFiles!.isNotEmpty) {
      _allImages = widget.imageFiles!;
    } else {
      _allImages = [widget.imageFile!];
    }

    _loadThumbnails();
    _startAnalysis();
  }

  Future<void> _loadThumbnails() async {
    for (int i = 0; i < _allImages.length; i++) {
      final bytes = await _allImages[i].readAsBytes();
      if (mounted) {
        setState(() => _thumbs[i] = bytes);
      }
    }
  }

  Future<void> _startAnalysis() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final NutritionResult result;

      if (_allImages.length > 1) {
        // Multi-image analysis
        result = await apiService.analyzeMultipleImages(_allImages);
      } else {
        // Single image analysis
        result = await apiService.analyzeImage(_allImages.first);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ResultsScreen(result: result, imageFile: _allImages.first),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMulti = _allImages.length > 1;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_hasError) ...[
                // Image Preview(s) with Scanning Effect
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Show image grid or single image
                    if (isMulti)
                      _MultiImagePreview(thumbs: _thumbs, count: _allImages.length)
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: _thumbs[0] != null
                            ? Image.memory(
                                _thumbs[0]!,
                                width: 280,
                                height: 280,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox(
                                width: 280,
                                height: 280,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                      ),
                    // Scanning overlay
                    SizedBox(
                      width: 320,
                      height: 320,
                      child: const Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.document_scanner_outlined,
                              size: 80, color: Colors.green),
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'Identifying Food...',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  isMulti
                      ? 'Analyzing ${_allImages.length} images for accurate results.'
                      : 'Our AI is analyzing the nutrients in your meal.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (isMulti) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.burst_mode_rounded,
                            color: AppTheme.primaryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${_allImages.length} angles captured',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const Icon(Icons.error_outline_rounded,
                    size: 80, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  'Analysis Failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Unknown error occurred',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A 2x2 grid preview of multiple images during scanning
class _MultiImagePreview extends StatelessWidget {
  final Map<int, Uint8List> thumbs;
  final int count;

  const _MultiImagePreview({required this.thumbs, required this.count});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        width: 280,
        height: 280,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: count.clamp(1, 4),
          itemBuilder: (context, index) {
            final bytes = thumbs[index];
            return bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color: Colors.white.withOpacity(0.05),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
          },
        ),
      ),
    );
  }
}
