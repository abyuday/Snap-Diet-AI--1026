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

  void _onSearch() async {
    final query = _searchController.text.trim();
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
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Manual Search',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onSubmitted: (_) => _onSearch(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Try 'Chicken Biryani'...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF161B22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0D1117)),
                    onPressed: _onSearch,
                  ),
                )
              ],
            ),
          ),
          
          if (_results.isEmpty && !_isLoading) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nutrient Database', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFeatureBadge(Icons.spellcheck, 'Fuzzy matching', const Color(0xFF6366F1)),
                        _buildFeatureBadge(Icons.verified, 'Verified', const Color(0xFF4ADE80)),
                        _buildFeatureBadge(Icons.offline_bolt, 'Offline fallback', const Color(0xFFFBBF24)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent searches', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildRecentSearch('Apple'),
                      _buildRecentSearch('Chicken Breast'),
                      _buildRecentSearch('Rice'),
                    ],
                  )
                ],
              ),
            )
          ],
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : ListView.builder(
                    itemCount: _results.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return _SearchTile(item: item);
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecentSearch(String text) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        _onSearch();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  final dynamic item;
  const _SearchTile({required this.item});

  bool get _isCounted {
    final name = (item['name'] as String).toLowerCase();
    const countedFoods = [
      'idli', 'dosa', 'vada', 'samosa', 'roti', 'chapati', 'paratha', 'naan',
      'egg', 'apple', 'banana', 'orange', 'mango', 'guava', 'lemon',
      'cookie', 'biscuit', 'bread', 'toast',
    ];
    return countedFoods.any((f) => name.contains(f));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(item['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${item['calories']} kcal • ${item['protein']}P ${item['carbs']}C ${item['fat']}F', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showQuantityDialog(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: const Icon(Icons.add, color: AppTheme.primaryColor, size: 20),
            ),
          )
        ],
      ),
    );
  }

  void _showQuantityDialog(BuildContext context) {
    final isCounted = _isCounted;
    final defaultVal = isCounted ? 1.0 : 100.0;
    String selectedUnit = isCounted ? 'pieces' : 'grams';
    final TextEditingController quantityController = TextEditingController(text: defaultVal.toStringAsFixed(0));
    
    final double stdPortionGrams = double.tryParse(item['standard_portion_grams']?.toString() ?? '0') ?? 0.0;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Text(item['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 16),
                        Expanded(child: Text(item['name'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Text('Portion Size', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF161B22),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedUnit,
                                dropdownColor: const Color(0xFF1E293B),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                items: [
                                  if (isCounted) const DropdownMenuItem(value: 'pieces', child: Text('Pieces')),
                                  const DropdownMenuItem(value: 'grams', child: Text('Grams')),
                                  const DropdownMenuItem(value: 'servings', child: Text('Servings')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedUnit = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final double inputVal = double.tryParse(quantityController.text) ?? 1.0;
                          double multiplier;
                          String portionLabel;

                          if (selectedUnit == 'servings') {
                            final double totalGrams = inputVal * (stdPortionGrams > 0 ? stdPortionGrams : 100.0);
                            multiplier = totalGrams / 100.0;
                            portionLabel = '${inputVal.toStringAsFixed(1)} serving${inputVal != 1.0 ? "s" : ""}';
                          } else if (isCounted && selectedUnit == 'pieces') {
                            final double totalGrams = inputVal * (stdPortionGrams > 0 ? stdPortionGrams : 100.0);
                            multiplier = totalGrams / 100.0;
                            portionLabel = '${inputVal.toStringAsFixed(0)} ${inputVal == 1.0 ? "piece" : "pieces"}';
                          } else {
                            multiplier = inputVal / 100.0;
                            portionLabel = '${inputVal.toStringAsFixed(0)}g';
                          }

                          final result = NutritionResult(
                            foodName: item['name'],
                            portionSize: portionLabel,
                            calories: (item['calories'] as num).toDouble() * multiplier,
                            protein: (item['protein'] as num).toDouble() * multiplier,
                            carbs: (item['carbs'] as num).toDouble() * multiplier,
                            fat: (item['fat'] as num).toDouble() * multiplier,
                            fiberG: (item['fiber_g'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            sugarG: (item['sugar_g'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            sodiumMg: (item['sodium_mg'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            potassiumMg: (item['potassium_mg'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            vitaminAMcg: (item['vitamin_a_mcg'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            vitaminCMg: (item['vitamin_c_mg'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            calciumMg: (item['calcium_mg'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            ironMg: (item['iron_mg'] as num?)?.toDouble() ?? 0.0 * multiplier,
                            rawData: {
                              'engine': 'Manual Search',
                              'confidence': 1.0,
                            },
                          );

                          Navigator.pop(ctx);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => ResultsScreen(result: result, imageFile: null)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Log & Analyze', style: GoogleFonts.outfit(color: const Color(0xFF0D1117), fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
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
