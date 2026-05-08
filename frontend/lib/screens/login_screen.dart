import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login controllers
  final _loginEmailCtrl    = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // Signup controllers
  final _signupNameCtrl     = TextEditingController();
  final _signupEmailCtrl    = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();

  bool _isLoading     = false;
  bool _showLoginPass = false;
  bool _showSignPass  = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg.replaceAll(RegExp(r'\[.*?\]'), '')),
      backgroundColor: AppTheme.accentRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleLogin() async {
    if (_loginEmailCtrl.text.isEmpty || _loginPasswordCtrl.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await context.read<UserProvider>().login(
        _loginEmailCtrl.text.trim(),
        _loginPasswordCtrl.text,
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (_signupNameCtrl.text.isEmpty ||
        _signupEmailCtrl.text.isEmpty ||
        _signupPasswordCtrl.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await context.read<UserProvider>().signup(
        _signupNameCtrl.text.trim(),
        _signupEmailCtrl.text.trim(),
        _signupPasswordCtrl.text,
        2000, 120, 250, 70,
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? AppTheme.darkBg      : AppTheme.lightBg;
    final surf   = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final surf2  = isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2;
    final border = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;
    final accent = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Radial glow background
          Positioned(
            top: -80, left: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.06),
              ),
            ),
          ),

          // Theme toggle
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => context.read<ThemeProvider>().toggle(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: surf2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Icon(
                      isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      color: accent, size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // App icon
                  Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
                    ),
                    child: Icon(Icons.sentiment_satisfied_alt_rounded, color: accent, size: 40),
                  ),
                  const SizedBox(height: 20),

                  // Brand name
                  Text(
                    'Snap DietAI',
                    style: GoogleFonts.outfit(
                      fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your personal nutrition AI',
                    style: GoogleFonts.outfit(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 36),

                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        // Tabs
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          decoration: BoxDecoration(
                            color: surf2,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: textMuted,
                            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            tabs: const [
                              Tab(text: 'Sign In'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),

                        SizedBox(
                          height: 320,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoginTab(accent, textPrimary, textMuted, surf2, border),
                              _buildSignupTab(accent, textPrimary, textMuted, surf2, border),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Google button
                  _buildGoogleButton(surf, border, textPrimary),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildLoginTab(Color accent, Color textPrimary, Color textMuted,
      Color surf2, Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          _buildInput(
            controller: _loginEmailCtrl,
            hint: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            surf2: surf2, border: border, textMuted: textMuted,
          ),
          const SizedBox(height: 14),
          _buildInput(
            controller: _loginPasswordCtrl,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPass: _showLoginPass,
            onTogglePass: () => setState(() => _showLoginPass = !_showLoginPass),
            surf2: surf2, border: border, textMuted: textMuted,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text('Forgot Password?', style: TextStyle(color: accent, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          _buildPrimaryButton('Sign In', accent, _handleLogin),
        ],
      ),
    );
  }

  Widget _buildSignupTab(Color accent, Color textPrimary, Color textMuted,
      Color surf2, Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          _buildInput(
            controller: _signupNameCtrl,
            hint: 'Full name',
            icon: Icons.person_outline_rounded,
            surf2: surf2, border: border, textMuted: textMuted,
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: _signupEmailCtrl,
            hint: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            surf2: surf2, border: border, textMuted: textMuted,
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: _signupPasswordCtrl,
            hint: 'Create password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPass: _showSignPass,
            onTogglePass: () => setState(() => _showSignPass = !_showSignPass),
            surf2: surf2, border: border, textMuted: textMuted,
          ),
          const SizedBox(height: 20),
          _buildPrimaryButton('Create Account', accent, _handleSignup),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool showPass = false,
    VoidCallback? onTogglePass,
    TextInputType keyboardType = TextInputType.text,
    required Color surf2,
    required Color border,
    required Color textMuted,
  }) {
    final isDark = context.read<ThemeProvider>().isDark;
    return Container(
      decoration: BoxDecoration(
        color: surf2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !showPass,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textMuted, fontSize: 15),
          prefixIcon: Icon(icon, color: textMuted, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: textMuted, size: 18,
                  ),
                  onPressed: onTogglePass,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, Color accent, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildGoogleButton(Color surf, Color border, Color textPrimary) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Google login coming soon!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
        label: Text('Continue with Google', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary)),
        style: OutlinedButton.styleFrom(
          backgroundColor: surf,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
