import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/nutrition_result.dart';
import '../services/api_service.dart';
import '../services/history_provider.dart';
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
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
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
        title: Text('Search Food', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Try "Apple" or "Salmon"...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
        ],
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  final dynamic item;
  const _SearchTile({required this.item});

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
          child: Center(child: Text(item['emoji'], style: const TextStyle(fontSize: 24))),
        ),
        title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('${item['calories']} kcal per serving', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor),
        onTap: () {
          _showQuantityDialog(context);
        },
      ),
    );
  }

  void _showQuantityDialog(BuildContext context) {
    final TextEditingController quantityController = TextEditingController(text: '1.0');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Enter Quantity', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. 1.0 for standard serving, 2 for double',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                final double multiplier = double.tryParse(quantityController.text) ?? 1.0;
                Navigator.pop(context); // Close dialog
                
                final result = NutritionResult(
                  foodName: item['name'],
                  portionSize: '${multiplier}x Standard Serving',
                  calories: item['calories'].toDouble() * multiplier,
                  protein: item['protein'].toDouble() * multiplier,
                  carbs: item['carbs'].toDouble() * multiplier,
                  fat: item['fat'].toDouble() * multiplier,
                  rawData: {
                    'engine': 'Manual Search Override',
                    'confidence': 1.0,
                    'grounded_weight': true,
                    'methodology': 'Manual Selection'
                  }
                );
                
                // Close search screen and push ResultsScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ResultsScreen(result: result, imageFile: null)),
                );
              },
              child: const Text('Analyze', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }
}
