class NutritionResult {
  final String foodName;
  final String portionSize;
  final double estimatedWeightGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final double potassiumMg;
  final double vitaminAMcg;
  final double vitaminCMg;
  final double calciumMg;
  final double ironMg;
  final Map<String, dynamic>? rawData;

  NutritionResult({
    required this.foodName,
    required this.portionSize,
    this.estimatedWeightGrams = 0.0,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiberG = 0.0,
    this.sugarG = 0.0,
    this.sodiumMg = 0.0,
    this.potassiumMg = 0.0,
    this.vitaminAMcg = 0.0,
    this.vitaminCMg = 0.0,
    this.calciumMg = 0.0,
    this.ironMg = 0.0,
    this.rawData,
  });

  factory NutritionResult.fromJson(Map<String, dynamic> json) {
    return NutritionResult(
      foodName: json['food_name'] ?? 'Unknown',
      portionSize: json['portion_size'] ?? 'Unknown',
      estimatedWeightGrams: (json['estimated_weight_grams'] as num?)?.toDouble() ?? 0.0,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0.0,
      sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      potassiumMg: (json['potassium_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminAMcg: (json['vitamin_a_mcg'] as num?)?.toDouble() ?? 0.0,
      vitaminCMg: (json['vitamin_c_mg'] as num?)?.toDouble() ?? 0.0,
      calciumMg: (json['calcium_mg'] as num?)?.toDouble() ?? 0.0,
      ironMg: (json['iron_mg'] as num?)?.toDouble() ?? 0.0,
      rawData: json['raw_data'],
    );
  }
}
