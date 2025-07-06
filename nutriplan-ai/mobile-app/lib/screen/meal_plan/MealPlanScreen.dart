// File: nutriplan-ai/mobile-app/lib/screens/meal_plan/MealPlanScreen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MealPlanScreen extends StatelessWidget {
  const MealPlanScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> meals = const [
    {
      'type': 'Breakfast',
      'items': ['Oatmeal', 'Banana', 'Almonds'],
      'calories': 350,
      'protein': 15,
      'carbs': 50,
      'fat': 10,
    },
    {
      'type': 'Lunch',
      'items': ['Grilled Chicken', 'Quinoa', 'Green Salad'],
      'calories': 550,
      'protein': 30,
      'carbs': 40,
      'fat': 20,
    },
    {
      'type': 'Dinner',
      'items': ['Veg Soup', 'Brown Bread', 'Boiled Egg'],
      'calories': 450,
      'protein': 20,
      'carbs': 30,
      'fat': 15,
    },
  ];

  @override
  Widget build(BuildContext context) {
    int totalCalories = meals.fold(0, (sum, item) => sum + item['calories']);
    int totalProtein = meals.fold(0, (sum, item) => sum + item['protein']);
    int totalCarbs = meals.fold(0, (sum, item) => sum + item['carbs']);
    int totalFat = meals.fold(0, (sum, item) => sum + item['fat']);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Meal Plan"),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF2FFF4),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(
              calories: totalCalories,
              protein: totalProtein,
              carbs: totalCarbs,
              fat: totalFat),
          const SizedBox(height: 20),
          ...meals.map((meal) => _buildMealCard(meal)).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      {required int calories,
      required int protein,
      required int carbs,
      required int fat}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: const Color(0xFFB2DFDB),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Daily Summary",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBox("Calories", "$calories kcal"),
                _statBox("Protein", "$protein g"),
                _statBox("Carbs", "$carbs g"),
                _statBox("Fat", "$fat g"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal[900])),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.teal[700])),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meal['type'],
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...meal['items'].map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6),
                      const SizedBox(width: 6),
                      Text(item,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.grey[800])),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroIcon("Kcal", Icons.local_fire_department,
                    "${meal['calories']} kcal"),
                _macroIcon("Protein", Icons.fitness_center,
                    "${meal['protein']} g"),
                _macroIcon("Carbs", Icons.energy_savings_leaf,
                    "${meal['carbs']} g"),
                _macroIcon("Fat", Icons.opacity, "${meal['fat']} g"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _macroIcon(String label, IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w500)),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
