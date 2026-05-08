import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 — Name / Age / Gender
  final _nameCtrl = TextEditingController();
  final _ageCtrl  = TextEditingController();
  String _gender  = '';

  // Step 2 — Height / Weight / Target Weight
  final _heightCtrl       = TextEditingController();
  final _weightCtrl       = TextEditingController();
  final _targetWeightCtrl = TextEditingController();

  // Step 3 — Activity Level
  String _activityLevel = '';

  // Step 4 — Goal
  String _goal = '';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_validateStep()) return;
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  bool _validateStep() {
    switch (_currentStep) {
      case 0:
        if (_nameCtrl.text.isEmpty || _ageCtrl.text.isEmpty || _gender.isEmpty) {
          _showError('Please fill in all fields');
          return false;
        }
        break;
      case 1:
        if (_heightCtrl.text.isEmpty || _weightCtrl.text.isEmpty || _targetWeightCtrl.text.isEmpty) {
          _showError('Please fill in all fields');
          return false;
        }
        break;
      case 2:
        if (_activityLevel.isEmpty) {
          _showError('Please select your activity level');
          return false;
        }
        break;
      case 3:
        if (_goal.isEmpty) {
          _showError('Please select your goal');
          return false;
        }
        break;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.accentRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Mifflin-St Jeor BMR → TDEE → macros
  Map<String, int> _calculateGoals() {
    final age    = int.tryParse(_ageCtrl.text)    ?? 25;
    final height = double.tryParse(_heightCtrl.text)   ?? 170;
    final weight = double.tryParse(_weightCtrl.text)   ?? 70;

    double bmr = _gender == 'female'
        ? 10 * weight + 6.25 * height - 5 * age - 161
        : 10 * weight + 6.25 * height - 5 * age + 5;

    double actFactor = _activityLevel == 'low' ? 1.375
        : _activityLevel == 'high' ? 1.725
        : 1.55;

    double tdee = bmr * actFactor;
    if (_goal == 'weight_loss')   tdee -= 300;
    if (_goal == 'muscle_gain')   tdee += 200;

    int cal     = tdee.round();
    int protein = (weight * 1.8).round();                    // ~1.8g per kg
    int fat     = (tdee * 0.25 / 9).round();                 // 25% calories from fat
    int carbs   = ((tdee - protein * 4 - fat * 9) / 4).round();
    int water   = (weight * 35).round();                     // 35ml per kg

    return {
      'calories': max(cal, 1200),
      'protein':  max(protein, 50),
      'carbs':    max(carbs, 100),
      'fat':      max(fat, 30),
      'water':    max(water, 2000),
    };
  }

  Future<void> _finish() async {
    if (!_validateStep()) return;
    setState(() => _isSubmitting = true);

    final goals = _calculateGoals();
    try {
      await context.read<UserProvider>().completeOnboarding(
        age:            int.tryParse(_ageCtrl.text) ?? 25,
        gender:         _gender,
        heightCm:       double.tryParse(_heightCtrl.text) ?? 170,
        weightKg:       double.tryParse(_weightCtrl.text) ?? 70,
        targetWeightKg: double.tryParse(_targetWeightCtrl.text) ?? 65,
        activityLevel:  _activityLevel,
        goal:           _goal,
        calorieGoal:    goals['calories']!,
        proteinGoal:    goals['protein']!,
        carbsGoal:      goals['carbs']!,
        fatGoal:        goals['fat']!,
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? AppTheme.darkBg      : AppTheme.lightBg;
    final surf   = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final accent = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  // Step indicators
                  Row(
                    children: List.generate(4, (i) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _currentStep ? accent : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of 4',
                        style: GoogleFonts.outfit(color: textMuted, fontSize: 13),
                      ),
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: _back,
                          child: Text('Back', style: TextStyle(color: accent)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Pages ──────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(surf, accent, textPrimary, textMuted, isDark),
                  _buildStep2(surf, accent, textPrimary, textMuted, isDark),
                  _buildStep3(surf, accent, textPrimary, textMuted, isDark),
                  _buildStep4(surf, accent, textPrimary, textMuted, isDark),
                ],
              ),
            ),

            // ── Footer button ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _currentStep == 3 ? 'Get Started 🚀' : 'Continue →',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Name, Age, Gender
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep1(Color surf, Color accent, Color textPrimary, Color textMuted, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon('👋', accent),
          const SizedBox(height: 20),
          Text('Tell us about yourself', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text('We\'ll personalise your experience', style: GoogleFonts.outfit(fontSize: 14, color: textMuted)),
          const SizedBox(height: 32),
          _label('Your Name', textMuted),
          _textField(_nameCtrl, 'Enter your name', Icons.person_outline_rounded, surf, isDark, textMuted),
          const SizedBox(height: 20),
          _label('Age', textMuted),
          _textField(_ageCtrl, 'e.g. 25', Icons.cake_outlined, surf, isDark, textMuted,
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _label('Gender', textMuted),
          const SizedBox(height: 10),
          Row(
            children: [
              _genderChip('Male',   'male',   '♂',  accent, surf, textPrimary, textMuted, isDark),
              const SizedBox(width: 12),
              _genderChip('Female', 'female', '♀',  accent, surf, textPrimary, textMuted, isDark),
              const SizedBox(width: 12),
              _genderChip('Other',  'other',  '⚧',  accent, surf, textPrimary, textMuted, isDark),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Height, Weight, Target Weight
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep2(Color surf, Color accent, Color textPrimary, Color textMuted, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon('📏', accent),
          const SizedBox(height: 20),
          Text('Your body stats', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text('Used to calculate your daily needs', style: GoogleFonts.outfit(fontSize: 14, color: textMuted)),
          const SizedBox(height: 32),
          _label('Height (cm)', textMuted),
          _textField(_heightCtrl, 'e.g. 170', Icons.height_rounded, surf, isDark, textMuted,
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _label('Current Weight (kg)', textMuted),
          _textField(_weightCtrl, 'e.g. 70', Icons.monitor_weight_outlined, surf, isDark, textMuted,
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _label('Target Weight (kg)', textMuted),
          _textField(_targetWeightCtrl, 'e.g. 65', Icons.flag_outlined, surf, isDark, textMuted,
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — Activity Level
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep3(Color surf, Color accent, Color textPrimary, Color textMuted, bool isDark) {
    final levels = [
      {'value': 'low',    'label': 'Low',    'sub': 'Mostly sedentary, desk job',       'icon': '🧘'},
      {'value': 'medium', 'label': 'Medium', 'sub': '3–5 workouts per week',            'icon': '🚶'},
      {'value': 'high',   'label': 'High',   'sub': 'Daily intense exercise',           'icon': '🏋️'},
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon('⚡', accent),
          const SizedBox(height: 20),
          Text('Activity Level', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text('How active are you on a typical week?', style: GoogleFonts.outfit(fontSize: 14, color: textMuted)),
          const SizedBox(height: 32),
          ...levels.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _selectCard(
              value:    l['value']!,
              label:    l['label']!,
              sub:      l['sub']!,
              emoji:    l['icon']!,
              selected: _activityLevel,
              accent:   accent,
              surf:     surf,
              textPrimary: textPrimary,
              textMuted:   textMuted,
              isDark:   isDark,
              onTap:    (v) => setState(() => _activityLevel = v),
            ),
          )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 4 — Goal
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep4(Color surf, Color accent, Color textPrimary, Color textMuted, bool isDark) {
    final goals = [
      {'value': 'weight_loss',  'label': 'Weight Loss',   'sub': 'Lose fat and feel lighter',            'icon': '🔥'},
      {'value': 'muscle_gain',  'label': 'Muscle Gain',   'sub': 'Build strength and lean mass',         'icon': '💪'},
      {'value': 'maintenance',  'label': 'Maintenance',   'sub': 'Stay at current weight, feel healthy', 'icon': '⚖️'},
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon('🎯', accent),
          const SizedBox(height: 20),
          Text('Your Main Goal', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text('We\'ll tailor your calorie targets to match', style: GoogleFonts.outfit(fontSize: 14, color: textMuted)),
          const SizedBox(height: 32),
          ...goals.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _selectCard(
              value:    g['value']!,
              label:    g['label']!,
              sub:      g['sub']!,
              emoji:    g['icon']!,
              selected: _goal,
              accent:   accent,
              surf:     surf,
              textPrimary: textPrimary,
              textMuted:   textMuted,
              isDark:   isDark,
              onTap:    (v) => setState(() => _goal = v),
            ),
          )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _stepIcon(String emoji, Color accent) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
    );
  }

  Widget _label(String text, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    Color surf,
    bool isDark,
    Color textMuted, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surf2  = isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2;
    return Container(
      decoration: BoxDecoration(
        color: surf2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textMuted),
          prefixIcon: Icon(icon, color: textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _genderChip(String label, String value, String symbol, Color accent,
      Color surf, Color textPrimary, Color textMuted, bool isDark) {
    final selected = _gender == value;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.15) : (isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.outfit(fontSize: 12, color: selected ? accent : textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectCard({
    required String value,
    required String label,
    required String sub,
    required String emoji,
    required String selected,
    required Color accent,
    required Color surf,
    required Color textPrimary,
    required Color textMuted,
    required bool isDark,
    required ValueChanged<String> onTap,
  }) {
    final isSelected = selected == value;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.12) : (isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? accent : textPrimary)),
                  const SizedBox(height: 2),
                  Text(sub, style: GoogleFonts.outfit(fontSize: 13, color: textMuted)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
