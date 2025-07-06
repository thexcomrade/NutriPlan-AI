// 📍 File: lib/screens/recommendation/recommendation_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];
  final Map<String, List<Map<String, dynamic>>> _recommendations = {
    'Breakfast': [
      {
        "item": "Oats with Banana & Peanut Butter",
        "calories": 350,
        "tags": ["Protein-rich", "Budget-friendly", "Vegan"]
      },
      {
        "item": "Boiled Eggs & Whole Wheat Toast",
        "calories": 400,
        "tags": ["High Protein", "Muscle Gain"]
      }
    ],
    'Lunch': [
      {
        "item": "Brown Rice, Grilled Chicken & Veggies",
        "calories": 500,
        "tags": ["Balanced", "Budget"]
      },
      {
        "item": "Paneer Wrap with Curd",
        "calories": 450,
        "tags": ["Protein-rich", "Vegetarian"]
      }
    ],
    'Snacks': [
      {
        "item": "Mixed Nuts & Green Tea",
        "calories": 200,
        "tags": ["Keto-friendly", "Healthy Fats"]
      }
    ],
    'Dinner': [
      {
        "item": "Millets + Stir Fry Veggies",
        "calories": 400,
        "tags": ["Light", "Gluten-Free"]
      },
      {
        "item": "Chicken Clear Soup & Multigrain Bread",
        "calories": 380,
        "tags": ["Low Carb", "Digestive"]
      }
    ],
  };

  @override
  void initState() {
    _tabController = TabController(length: _tabs.length, vsync: this);
    super.initState();
  }

  Widget _buildRecommendationCard(Map<String, dynamic> data) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['item'],
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text("${data['calories']} kcal", style: GoogleFonts.poppins(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: List.generate(
                  data['tags'].length,
                  (index) => Chip(
                    label: Text(data['tags'][index], style: GoogleFonts.poppins(fontSize: 12)),
                    backgroundColor: Colors.green.shade100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTab(String mealType) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recommendations[mealType]!.length,
      itemBuilder: (context, index) {
        final rec = _recommendations[mealType]![index];
        return _buildRecommendationCard(rec);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Diet Plan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(child: Text(tab, style: GoogleFonts.poppins()))).toList(),
          isScrollable: true,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildMealTab(tab)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Fetch new recommendations via ML API
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("New plan generation coming soon!"),
          ));
        },
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
