import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/nutrition_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final results = await apiService.searchFoods(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
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
          'Search Food',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Try "Idli", "Chicken Biryani", "Apple"...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.5)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _results.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _results.length,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return _SearchTile(item: item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Search for any food item' : 'No results found',
            style: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try a different spelling',
              style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
            ),
          ]
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Result Tile — opens the smart quantity dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SearchTile extends StatelessWidget {
  final dynamic item;
  const _SearchTile({required this.item});

  // Determine if this food is typically counted by pieces vs measured by weight
  bool get _isCounted {
    final name = (item['name'] as String).toLowerCase();
    const countedFoods = [
      'idli', 'dosa', 'vada', 'samosa', 'roti', 'chapati', 'paratha', 'naan',
      'egg', 'apple', 'banana', 'orange', 'mango', 'guava', 'lemon',
      'cookie', 'biscuit', 'bread', 'toast',
    ];
    return countedFoods.any((f) => name.contains(f));
  }

  String get _unitLabel => _isCounted ? 'pieces' : 'grams';
  String get _unitHint => _isCounted ? 'e.g. 2 pieces' : 'e.g. 150 grams';
  double get _defaultValue => _isCounted ? 1.0 : 100.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(item['emoji'] ?? '🍽', style: const TextStyle(fontSize: 24))),
        ),
        title: Text(
          item['name'],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item['calories']} kcal · ${item['protein']}g protein per serving',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor),
        onTap: () => _showQuantityDialog(context),
      ),
    );
  }

  void _showQuantityDialog(BuildContext context) {
    // Determine unit type: pieces-based OR weight-based
    final isCounted = _isCounted;
    final unitLabel = _unitLabel;
    final defaultVal = _defaultValue;

    // "servings" tab is always available as a second option
    String selectedUnit = isCounted ? 'pieces' : 'grams';
    final TextEditingController quantityController =
        TextEditingController(text: defaultVal.toStringAsFixed(isCounted ? 0 : 0));

    // Standard portion grams (from search result), 0 means unknown
    final double stdPortionGrams =
        double.tryParse(item['standard_portion_grams']?.toString() ?? '0') ?? 0.0;
    final double caloriesPerServing = (item['calories'] as num).toDouble();
    final double proteinPerServing = (item['protein'] as num).toDouble();
    final double carbsPerServing = (item['carbs'] as num).toDouble();
    final double fatPerServing = (item['fat'] as num).toDouble();
    final double fiberPerServing = (item['fiber_g'] as num?)?.toDouble() ?? 0.0;
    final double sugarPerServing = (item['sugar_g'] as num?)?.toDouble() ?? 0.0;
    final double sodiumPerServing = (item['sodium_mg'] as num?)?.toDouble() ?? 0.0;
    final double potassiumPerServing = (item['potassium_mg'] as num?)?.toDouble() ?? 0.0;
    final double vitaminAPerServing = (item['vitamin_a_mcg'] as num?)?.toDouble() ?? 0.0;
    final double vitaminCPerServing = (item['vitamin_c_mg'] as num?)?.toDouble() ?? 0.0;
    final double calciumPerServing = (item['calcium_mg'] as num?)?.toDouble() ?? 0.0;
    final double ironPerServing = (item['iron_mg'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text(item['emoji'] ?? '🍽', style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['name'],
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Unit toggle chips
                    Text(
                      'How much did you eat?',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _UnitChip(
                          label: isCounted ? 'Pieces' : 'Grams',
                          icon: isCounted ? Icons.tag : Icons.monitor_weight_outlined,
                          selected: selectedUnit == unitLabel,
                          onTap: () => setDialogState(() {
                            selectedUnit = unitLabel;
                            quantityController.text = defaultVal.toStringAsFixed(0);
                          }),
                        ),
                        const SizedBox(width: 10),
                        _UnitChip(
                          label: 'Servings',
                          icon: Icons.restaurant_outlined,
                          selected: selectedUnit == 'servings',
                          onTap: () => setDialogState(() {
                            selectedUnit = 'servings';
                            quantityController.text = '1';
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount input
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: selectedUnit == 'servings' ? 'e.g. 1.5' : _unitHint,
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18),
                        suffix: Text(
                          selectedUnit,
                          style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.8), fontSize: 16),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.white.withOpacity(0.15)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final double inputVal = double.tryParse(quantityController.text) ?? 1.0;
                              // All nutrition in database is now standardized to "Per 100g"
                              double multiplier;
                              String portionLabel;

                              if (selectedUnit == 'servings') {
                                // Scale based on standard portion weight
                                final double totalGrams = inputVal * (stdPortionGrams > 0 ? stdPortionGrams : 100.0);
                                multiplier = totalGrams / 100.0;
                                portionLabel = '${inputVal.toStringAsFixed(1)} serving${inputVal != 1.0 ? "s" : ""}';
                              } else if (isCounted && selectedUnit == 'pieces') {
                                // Scale based on standard weight of ONE piece
                                final double totalGrams = inputVal * (stdPortionGrams > 0 ? stdPortionGrams : 100.0);
                                multiplier = totalGrams / 100.0;
                                portionLabel = '${inputVal.toStringAsFixed(0)} ${inputVal == 1.0 ? "piece" : "pieces"}';
                              } else {
                                // Forgrams/weight: direct division by 100
                                multiplier = inputVal / 100.0;
                                portionLabel = '${inputVal.toStringAsFixed(0)}g';
                              }

                              final result = NutritionResult(
                                foodName: item['name'],
                                portionSize: portionLabel,
                                calories: caloriesPerServing * multiplier,
                                protein: proteinPerServing * multiplier,
                                carbs: carbsPerServing * multiplier,
                                fat: fatPerServing * multiplier,
                                fiberG: fiberPerServing * multiplier,
                                sugarG: sugarPerServing * multiplier,
                                sodiumMg: sodiumPerServing * multiplier,
                                potassiumMg: potassiumPerServing * multiplier,
                                vitaminAMcg: vitaminAPerServing * multiplier,
                                vitaminCMg: vitaminCPerServing * multiplier,
                                calciumMg: calciumPerServing * multiplier,
                                ironMg: ironPerServing * multiplier,
                                rawData: {
                                  'engine': 'Manual Search',
                                  'confidence': 1.0,
                                  'grounded_weight': true,
                                  'methodology': 'Manual Selection',
                                },
                              );

                              Navigator.pop(ctx);
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (c, a, b) => ResultsScreen(result: result, imageFile: null),
                                  transitionsBuilder: (c, a, b, child) =>
                                      FadeTransition(opacity: a, child: child),
                                  transitionDuration: const Duration(milliseconds: 400),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'Log & Analyze',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _UnitChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _UnitChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.white.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.5),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
