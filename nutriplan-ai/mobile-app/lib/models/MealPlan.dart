// 📍 File: lib/models/meal_plan.dart

class MealPlan {
  final String userId;
  final DateTime date;
  final Meal breakfast;
  final Meal lunch;
  final Meal dinner;
  final List<Meal> snacks; // Optional snacks between meals
  final NutritionalInfo dailyNutrition;
  final String recommendationNote;
  final String dietType; // protein-rich, budget-friendly, etc.

  MealPlan({
    required this.userId,
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snacks,
    required this.dailyNutrition,
    required this.recommendationNote,
    required this.dietType,
  });

  /// Factory constructor from JSON
  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      userId: json['userId'],
      date: DateTime.parse(json['date']),
      breakfast: Meal.fromJson(json['breakfast']),
      lunch: Meal.fromJson(json['lunch']),
      dinner: Meal.fromJson(json['dinner']),
      snacks: (json['snacks'] as List<dynamic>)
          .map((e) => Meal.fromJson(e))
          .toList(),
      dailyNutrition: NutritionalInfo.fromJson(json['dailyNutrition']),
      recommendationNote: json['recommendationNote'],
      dietType: json['dietType'],
    );
  }

  /// Convert to JSON for backend or local storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'date': date.toIso8601String(),
      'breakfast': breakfast.toJson(),
      'lunch': lunch.toJson(),
      'dinner': dinner.toJson(),
      'snacks': snacks.map((e) => e.toJson()).toList(),
      'dailyNutrition': dailyNutrition.toJson(),
      'recommendationNote': recommendationNote,
      'dietType': dietType,
    };
  }
}

class Meal {
  final String title;
  final List<String> items;
  final NutritionalInfo nutrition;
  final int estimatedCost; // in INR

  Meal({
    required this.title,
    required this.items,
    required this.nutrition,
    required this.estimatedCost,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      title: json['title'],
      items: List<String>.from(json['items']),
      nutrition: NutritionalInfo.fromJson(json['nutrition']),
      estimatedCost: json['estimatedCost'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'items': items,
      'nutrition': nutrition.toJson(),
      'estimatedCost': estimatedCost,
    };
  }
}

class NutritionalInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;
  final double sugar;

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.sugar,
  });

  factory NutritionalInfo.fromJson(Map<String, dynamic> json) {
    return NutritionalInfo(
      calories: json['calories'].toDouble(),
      protein: json['protein'].toDouble(),
      carbs: json['carbs'].toDouble(),
      fats: json['fats'].toDouble(),
      fiber: json['fiber'].toDouble(),
      sugar: json['sugar'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'fiber': fiber,
      'sugar': sugar,
    };
  }

  /// Optional: Get nutritional summary string
  String get summary => '''
Calories: ${calories.toStringAsFixed(0)} kcal
Protein: ${protein.toStringAsFixed(1)} g
Carbs: ${carbs.toStringAsFixed(1)} g
Fats: ${fats.toStringAsFixed(1)} g
Fiber: ${fiber.toStringAsFixed(1)} g
Sugar: ${sugar.toStringAsFixed(1)} g
''';
}
