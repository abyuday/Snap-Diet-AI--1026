import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/nutrition_result.dart';
import 'results_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final XFile imageFile;

  const AnalysisScreen({super.key, required this.imageFile});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _hasError = false;
  String? _errorMessage;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadBytes();
    _startAnalysis();
  }

  Future<void> _loadBytes() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (mounted) {
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _startAnalysis() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.analyzeImage(widget.imageFile);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(result: result, imageFile: widget.imageFile),
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_hasError) ...[
                // Image Preview with Scanning Effect
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: _imageBytes != null 
                        ? Image.memory(
                            _imageBytes!,
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
                    // Premium Scanning Lottie overlay
                    SizedBox(
                      width: 320,
                      height: 320,
                      child: Lottie.network(
                        'https://assets9.lottiefiles.com/packages/lf20_unp9id9m.json', // A cool scanning/radar effect
                        errorBuilder: (context, error, stackTrace) {
                          return const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          );
                        },
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
                const Text(
                  'Our AI is analyzing the nutrients in your meal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ] else ...[
                const Icon(Icons.error_outline_rounded, size: 80, color: Colors.red),
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
