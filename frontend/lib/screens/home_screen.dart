import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/history_provider.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'multi_capture_screen.dart';
import 'search_screen.dart';
import 'chat_screen.dart';
import 'main_shell.dart';
import 'voice_log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MultiCaptureScreen(initialImages: [image]),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _openMultiCapture() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MultiCaptureScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 0.9,
            colors: [
              AppTheme.primaryColor.withOpacity(0.15),
              AppTheme.backgroundColor,
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                _buildTopBar(),
                const SizedBox(height: 32),
                _buildHeroSection(),
                const SizedBox(height: 32),
                _buildChatCard(context),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildSearchButton(context),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAdviceSheet(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.14),
              AppTheme.primaryColor.withOpacity(0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need diet advice?',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Tap for personalised tips based on your habits',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primaryColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdviceSheet(BuildContext context) {
    final history = Provider.of<HistoryProvider>(context, listen: false);
    final calToday = history.totalToday;
    final protToday = history.totalProteinToday;
    final carbsToday = history.totalCarbsToday;
    final fatToday = history.totalFatToday;
    final scanCount = history.history.length;

    // Generate personalised tips from actual data
    final tips = _buildPersonalisedTips(calToday, protToday, carbsToday, fatToday, scanCount);

    // Smart chat prompts
    final prompts = [
      '💪 How can I increase my protein intake with Indian food?',
      '🥗 What are some healthy low-calorie Indian snacks?',
      '🍳 Give me a healthy high-protein breakfast recipe',
      '🌙 What should I eat for dinner to lose weight?',
      '💧 How much water should I drink daily?',
      '🫚 What healthy fats should I include in my Indian diet?',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Material(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded,
                              color: AppTheme.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Diet Advice',
                                style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text('Personalised from your food history',
                                style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Today's snapshot
                    if (scanCount > 0) ...[
                      _sheetSectionTitle('📊 Today\'s Snapshot'),
                      const SizedBox(height: 12),
                      _todayStatsRow(calToday, protToday, carbsToday, fatToday),
                      const SizedBox(height: 24),
                    ],

                    // Personalised tips
                    _sheetSectionTitle('💡 Personalised Tips'),
                    const SizedBox(height: 12),
                    ...tips.map((tip) => _TipCard(tip: tip)),
                    const SizedBox(height: 24),

                    // Ask AI section
                    _sheetSectionTitle('🤖 Ask SnapDiet AI'),
                    const SizedBox(height: 12),
                    Text(
                      'Tap any question to get an instant AI answer:',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: prompts.map((p) => _PromptChip(
                        label: p,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToChatWithPrompt(context, p);
                        },
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _buildPersonalisedTips(
      double cal, double prot, double carbs, double fat, int scans) {
    final tips = <Map<String, String>>[];

    if (scans == 0) {
      tips.add({
        'icon': '🍱',
        'title': 'Start Logging Meals',
        'body':
            'Log your first meal today! Snap a photo or search manually — the more you log, the better your personalised advice gets.',
      });
      tips.add({
        'icon': '🥗',
        'title': 'Balanced Indian Plate',
        'body':
            'A balanced Indian meal should include 50% vegetables, 25% whole grains (roti/brown rice), and 25% protein (dal, paneer, chicken).',
      });
      tips.add({
        'icon': '💧',
        'title': 'Start Your Day Right',
        'body':
            'Drink 1–2 glasses of warm water in the morning before eating. It boosts metabolism and aids digestion throughout the day.',
      });
    } else {
      if (prot < 50) {
        tips.add({
          'icon': '🥚',
          'title': 'Boost Your Protein!',
          'body':
              'You\'ve only had ${prot.toInt()}g of protein today. Try adding eggs, paneer, moong dal, or a handful of peanuts to your next meal.',
        });
      } else if (prot > 150) {
        tips.add({
          'icon': '✅',
          'title': 'Great Protein Intake!',
          'body':
              'You\'re at ${prot.toInt()}g protein today — excellent! Make sure to stay hydrated and include fiber-rich vegetables to aid absorption.',
        });
      }

      if (cal > 2200) {
        tips.add({
          'icon': '⚖️',
          'title': 'Calorie Check',
          'body':
              'You\'ve consumed ${cal.toInt()} kcal today. For the rest of the day, stick to light foods like salads, chaas (buttermilk), or a small bowl of fruit.',
        });
      } else if (cal < 800 && scans > 0) {
        tips.add({
          'icon': '🍛',
          'title': 'Don\'t Skip Meals!',
          'body':
              'Only ${cal.toInt()} kcal today — you need more fuel! Skipping meals slows your metabolism. Try a nutritious meal like dal khichdi or a protein smoothie.',
        });
      }

      if (carbs > 300) {
        tips.add({
          'icon': '🌾',
          'title': 'Watch the Carbs',
          'body':
              'Your carb intake is high (${carbs.toInt()}g). Swap white rice for brown rice, and maida rotis for whole wheat to slow glucose spikes.',
        });
      }

      if (fat > 80) {
        tips.add({
          'icon': '🫒',
          'title': 'Choose Healthy Fats',
          'body':
              'High fat day (${fat.toInt()}g). Prefer mustard oil or ghee in small quantities over refined oils. Avoid deep-fried snacks for the rest of today.',
        });
      }

      // Always add 1 general good-habit tip
      tips.add({
        'icon': '🌙',
        'title': 'Evening Habit Tip',
        'body':
            'Eat your last meal at least 2–3 hours before bedtime. It improves digestion and sleep quality. A light khichdi or dal soup is ideal.',
      });
    }

    // Always cap at 4 tips max
    return tips.take(4).toList();
  }

  Widget _sheetSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _todayStatsRow(double cal, double prot, double carbs, double fat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat('${cal.toInt()}', 'kcal', AppTheme.primaryColor),
          _vLine(),
          _miniStat('${prot.toInt()}g', 'Protein', const Color(0xFF4FA3E0)),
          _vLine(),
          _miniStat('${carbs.toInt()}g', 'Carbs', const Color(0xFFFF9057)),
          _vLine(),
          _miniStat('${fat.toInt()}g', 'Fat', const Color(0xFFFF6B8A)),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _vLine() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.08));

  void _navigateToChatWithPrompt(BuildContext context, String prompt) {
    // Navigate to tab index 2 (ChatScreen) in MainShell and pre-fill the prompt
    // We use a shared approach via NavigatorState if available
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PrefilledChatScreen(initialPrompt: prompt),
      ),
    );
  }



  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello 👋', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
            const Text('SnapDiet AI', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_pulseAnim, _floatAnim]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
            );
          },
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Snap & Know\nYour Nutrition',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Take a photo of any food and get instant\naccurate nutritional insights powered by AI.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final scanCount = historyProvider.history.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🍎', 'Scans', '$scanCount'),
          _buildDivider(),
          _buildStatItem('🔥', 'Foods', '500+'),
          _buildDivider(),
          _buildStatItem('⚡', 'Accuracy', '97%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08));
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ScanButton(
                label: 'Scan Food',
                icon: Icons.camera_alt_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF56C27B), Color(0xFF2E7D32)],
                ),
                onTap: _openMultiCapture,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScanButton(
                label: 'Voice Log',
                icon: Icons.mic_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, a, __) => const VoiceLogScreen(),
                      transitionsBuilder: (_, a, __, child) =>
                          FadeTransition(opacity: a, child: child),
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ScanButton(
          label: 'Choose from Gallery',
          icon: Icons.photo_library_rounded,
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.04),
            ],
          ),
          onTap: () => _pickImage(ImageSource.gallery),
          outlined: true,
        ),
      ],
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded,
                color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'OR LOG MANUALLY',
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool outlined;

  const _ScanButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(_pressController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            border: widget.outlined
                ? Border.all(color: Colors.white.withOpacity(0.15))
                : null,
            boxShadow: widget.outlined ? [] : [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tip card used inside the advice bottom sheet
// ─────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final Map<String, String> tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip['icon'] ?? '💡', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip['body'] ?? '',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tappable chip that pre-sends a prompt to AI
// ─────────────────────────────────────────────
class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Opens ChatScreen with a pre-sent message
// ─────────────────────────────────────────────
class _PrefilledChatScreen extends StatelessWidget {
  final String initialPrompt;
  const _PrefilledChatScreen({required this.initialPrompt});

  @override
  Widget build(BuildContext context) {
    return ChatScreen(autoPrompt: initialPrompt);
  }
}
