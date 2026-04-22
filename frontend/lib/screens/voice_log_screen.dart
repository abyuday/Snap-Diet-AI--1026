import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

/// Dedicated Voice Logging screen.
///
/// Flow:
///   1. User taps the mic → speech recorded live (transcript shown)
///   2. User taps Stop (or speaks naturally pauses)  
///   3. Transcript is sent to /analyze-text endpoint
///   4. ResultsScreen shows the nutrition breakdown
class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({super.key});

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isAnalyzing = false;
  String _transcript = '';
  String? _errorText;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _idleCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;
  late Animation<double> _idleAnim;

  // Quick suggest chips
  static const List<String> _suggestions = [
    '2 idlis with sambar',
    '1 bowl chicken biryani',
    '3 rotis with dal',
    '1 plate masala dosa',
    'Oats with banana and milk',
    '2 boiled eggs and toast',
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _waveAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut),
    );
    _idleAnim = Tween<double>(begin: 0.92, end: 1.04).animate(
      CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut),
    );

    _initSpeech();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _idleCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => _stopListening(),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening) _stopListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      setState(() => _errorText = 'Microphone not available on this device.');
      return;
    }

    setState(() {
      _isListening = true;
      _transcript = '';
      _errorText = null;
    });

    // Animate
    _pulseCtrl.repeat(reverse: true);
    _waveCtrl.repeat(reverse: true);
    _idleCtrl.stop();

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _transcript = result.recognizedWords);
          if (result.finalResult) _stopListening();
        }
      },
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
    );
  }

  void _stopListening() {
    _speech.stop();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    _waveCtrl.stop();
    _waveCtrl.reset();
    _idleCtrl.repeat(reverse: true);
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _analyzeTranscript(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'Please say or type what you ate.');
      return;
    }

    if (_isListening) _stopListening();
    setState(() {
      _isAnalyzing = true;
      _errorText = null;
    });

    try {
      final result = await ApiService().analyzeText(trimmed);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ResultsScreen(result: result),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorText = 'Could not analyze. Check your server connection.';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice Log',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildMicSection(),
                    const SizedBox(height: 32),
                    _buildTranscriptCard(),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorBanner(),
                    ],
                    const SizedBox(height: 32),
                    _buildSuggestionsSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  Animated mic orb
  // ──────────────────────────────────────────

  Widget _buildMicSection() {
    return Column(
      children: [
        // Status text
        Text(
          _isListening
              ? 'Listening… speak now'
              : _isAnalyzing
                  ? 'Analyzing your food…'
                  : _speechAvailable
                      ? 'Tap the mic and say what you ate'
                      : 'Microphone not available',
          style: GoogleFonts.outfit(
            color: _isListening
                ? const Color(0xFF4FA3E0)
                : Colors.white.withOpacity(0.55),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Central mic orb
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings (visible only while listening)
              if (_isListening) ...[
                _RippleRing(controller: _waveCtrl, delay: 0.0, color: const Color(0xFF3B82F6)),
                _RippleRing(controller: _waveCtrl, delay: 0.3, color: const Color(0xFF3B82F6)),
                _RippleRing(controller: _waveCtrl, delay: 0.6, color: const Color(0xFF3B82F6)),
              ],
              // Outer glow ring (idle)
              AnimatedBuilder(
                animation: _isListening ? _pulseAnim : _idleAnim,
                builder: (_, child) => Transform.scale(
                  scale: _isListening ? _pulseAnim.value : _idleAnim.value,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _isListening
                            ? [
                                const Color(0xFF3B82F6).withOpacity(0.3),
                                const Color(0xFF1E40AF).withOpacity(0.05),
                              ]
                            : [
                                AppTheme.primaryColor.withOpacity(0.18),
                                AppTheme.primaryColor.withOpacity(0.03),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
              // Core button
              GestureDetector(
                onTap: _isAnalyzing
                    ? null
                    : (_isListening ? _stopListening : _startListening),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [const Color(0xFF2563EB), const Color(0xFF1E3A8A)]
                          : _isAnalyzing
                              ? [Colors.grey.shade700, Colors.grey.shade800]
                              : [
                                  AppTheme.primaryColor,
                                  AppTheme.secondaryColor,
                                ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? const Color(0xFF3B82F6)
                                : AppTheme.primaryColor)
                            .withOpacity(0.45),
                        blurRadius: 28,
                        spreadRadius: _isListening ? 8 : 4,
                      ),
                    ],
                  ),
                  child: _isAnalyzing
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        )
                      : Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Tap hint under mic
        if (!_isListening && !_isAnalyzing)
          Text(
            'Tap to start recording',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        if (_isListening)
          TextButton.icon(
            onPressed: _stopListening,
            icon: const Icon(Icons.stop_circle_rounded, color: Color(0xFF3B82F6)),
            label: const Text(
              'Done — Analyze',
              style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  Live transcript card
  // ──────────────────────────────────────────

  Widget _buildTranscriptCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isListening
              ? const Color(0xFF3B82F6).withOpacity(0.5)
              : Colors.white.withOpacity(0.07),
          width: _isListening ? 1.5 : 1.0,
        ),
        boxShadow: _isListening
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 16,
                color: _isListening
                    ? const Color(0xFF3B82F6)
                    : Colors.white.withOpacity(0.35),
              ),
              const SizedBox(width: 8),
              Text(
                _isListening ? 'Transcribing…' : 'What you said',
                style: TextStyle(
                  color: _isListening
                      ? const Color(0xFF3B82F6)
                      : Colors.white.withOpacity(0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isListening) ...[
                const SizedBox(width: 8),
                _PulseDot(),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _transcript.isEmpty
              ? Text(
                  _isListening
                      ? 'Start speaking…'
                      : 'Your speech will appear here',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Text(
                  '"${_transcript}"',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
          // Edit hint when done
          if (!_isListening && _transcript.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showEditDialog(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded,
                      size: 13, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to edit',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: _transcript);

    void _doUpdate(BuildContext dialogCtx) {
      setState(() => _transcript = ctrl.text);
      Navigator.pop(dialogCtx);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit your log',
            style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _doUpdate(dialogCtx),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            hintText: 'e.g. 2 idlis with sambar',
            hintStyle: const TextStyle(color: Colors.white24),
            helperText: 'Press Enter to confirm',
            helperStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => _doUpdate(dialogCtx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            child: Text(
              _errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  Quick suggestions
  // ──────────────────────────────────────────

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or tap a common meal',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _suggestions.map((s) {
            return GestureDetector(
              onTap: () {
                setState(() => _transcript = s);
                _analyzeTranscript(s);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.25)),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  Analyse button at bottom
  // ──────────────────────────────────────────

  Widget _buildBottomBar() {
    final hasText = _transcript.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed:
              (hasText && !_isAnalyzing && !_isListening)
                  ? () => _analyzeTranscript(_transcript)
                  : null,
          icon: _isAnalyzing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.restaurant_menu_rounded, size: 20),
          label: Text(
            _isAnalyzing
                ? 'Analyzing…'
                : hasText
                    ? 'Get Nutrition Breakdown'
                    : 'Speak or pick a suggestion',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasText && !_isAnalyzing
                ? AppTheme.primaryColor
                : Colors.white12,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withOpacity(0.06),
            disabledForegroundColor: Colors.white38,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────
//  Helper widgets
// ──────────────────────────────────────────────────

/// Animated ripple ring, used when mic is active.
class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _RippleRing({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final progress =
            ((controller.value + delay) % 1.0);
        final size = 110.0 + 90.0 * progress;
        return Opacity(
          opacity: (1.0 - progress).clamp(0.0, 0.5),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}

/// Animated green pulsing dot shown during transcription.
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
              const Color(0xFF3B82F6), Colors.lightBlueAccent, _ctrl.value),
        ),
      ),
    );
  }
}
