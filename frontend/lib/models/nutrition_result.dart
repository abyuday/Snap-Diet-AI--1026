class NutritionResult {
  final String foodName;
  final String portionSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final Map<String, dynamic>? rawData;

  NutritionResult({
    required this.foodName,
    required this.portionSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.rawData,
  });

  factory NutritionResult.fromJson(Map<String, dynamic> json) {
    return NutritionResult(
      foodName: json['food_name'] ?? 'Unknown',
      portionSize: json['portion_size'] ?? 'Unknown',
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      rawData: json['raw_data'],
    );
  }
}
