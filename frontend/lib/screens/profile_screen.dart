import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/user_provider.dart';
import '../services/history_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final historyProvider = Provider.of<HistoryProvider>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('My Profile', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              // Profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('👤', style: TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userProvider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(userProvider.rank, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showEditProfileDialog(context, userProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Edit', style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Stats row
              Row(
                children: [
                  Expanded(child: _StatBox(emoji: '🍽', value: '${historyProvider.history.length}', label: 'Meals Logged')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatBox(emoji: '🔥', value: '${historyProvider.totalToday.toInt()}', label: 'kcal Today')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatBox(emoji: '📅', value: '7', label: 'Day Streak')),
                ],
              ),
              const SizedBox(height: 28),
              Text('Daily Progress', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 14),
              _GoalTile(
                label: 'Calories', 
                current: historyProvider.totalToday.toInt(), 
                goal: userProvider.calorieGoal, 
                color: AppTheme.primaryColor,
                unit: 'kcal',
              ),
              const SizedBox(height: 10),
              _GoalTile(
                label: 'Protein', 
                current: historyProvider.totalProteinToday.toInt(), 
                goal: userProvider.proteinGoal, 
                color: const Color(0xFF4FA3E0),
                unit: 'g',
              ),
              const SizedBox(height: 10),
              _GoalTile(
                label: 'Carbs', 
                current: historyProvider.totalCarbsToday.toInt(), 
                goal: userProvider.carbsGoal, 
                color: const Color(0xFFFF9057),
                unit: 'g',
              ),
              const SizedBox(height: 10),
              _GoalTile(
                label: 'Hydration', 
                current: userProvider.currentWater, 
                goal: userProvider.waterGoal, 
                color: const Color(0xFF64B5F6),
                unit: 'ml',
                onTap: () => userProvider.addWater(250),
              ),
              const SizedBox(height: 28),
              Text('Settings', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 14),
              _SettingsTile(icon: Icons.info_outline_rounded, label: 'About', trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showGoalSettings(context, userProvider),
                child: _SettingsTile(
                  icon: Icons.track_changes_rounded, 
                  label: 'Adjust Daily Goals', 
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.read<UserProvider>().logout(),
                child: _SettingsTile(
                  icon: Icons.logout_rounded, 
                  label: 'Logout', 
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  isDestructive: true,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProvider userProvider) {
    final nameController = TextEditingController(text: userProvider.name);
    final rankController = TextEditingController(text: userProvider.rank);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profile', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rankController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Rank',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                userProvider.updateProfile(nameController.text.trim(), rankController.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showGoalSettings(BuildContext context, UserProvider user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Goal Settings', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            _buildSlider('Calories', user.calorieGoal.toDouble(), 1200, 3500, (v) => user.updateGoals(calories: v.toInt())),
            const SizedBox(height: 16),
            _buildSlider('Protein (g)', user.proteinGoal.toDouble(), 40, 250, (v) => user.updateGoals(protein: v.toInt())),
            const SizedBox(height: 16),
            _buildSlider('Water (ml)', user.waterGoal.toDouble(), 1000, 5000, (v) => user.updateGoals(water: v.toInt())),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Save Goals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text('${val.toInt()}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: val,
          min: min,
          max: max,
          activeColor: AppTheme.primaryColor,
          inactiveColor: Colors.white10,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final bool isDestructive;
  const _SettingsTile({required this.icon, required this.label, required this.trailing, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white54, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 15))),
          trailing,
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String emoji, value, label;
  const _StatBox({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10)),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final String label, unit;
  final int current, goal;
  final Color color;
  final VoidCallback? onTap;
  
  const _GoalTile({
    required this.label, 
    required this.current, 
    required this.goal, 
    required this.color, 
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (current / goal).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                Text('$current / $goal $unit', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.07),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _Switch extends StatefulWidget {
  const _Switch();

  @override
  State<_Switch> createState() => _SwitchState();
}

class _SwitchState extends State<_Switch> {
  bool _val = true;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _val,
      onChanged: (v) => setState(() => _val = v),
      activeColor: AppTheme.primaryColor,
    );
  }
}
