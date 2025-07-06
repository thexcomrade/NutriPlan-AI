// File: nutriplan-ai/mobile-app/lib/screens/onboarding/NutritionGoalForm.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dashboard/MainDashboard.dart';

class NutritionGoalForm extends StatefulWidget {
  final String lifestyle;
  final String disease;
  final String medications;
  final String allergies;

  const NutritionGoalForm({
    Key? key,
    required this.lifestyle,
    required this.disease,
    required this.medications,
    required this.allergies,
  }) : super(key: key);

  @override
  State<NutritionGoalForm> createState() => _NutritionGoalFormState();
}

class _NutritionGoalFormState extends State<NutritionGoalForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _goalController = TextEditingController();
  String selectedGoal = "";

  final List<String> goalOptions = [
    'Weight Loss',
    'Weight Gain',
    'Muscle Building',
    'Balanced Nutrition',
    'Diabetes-Friendly Diet',
    'Heart-Healthy Diet',
    'PCOS-Friendly Plan',
    'Digestive Health',
  ];

  void _submit() {
    if (selectedGoal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a goal to continue")),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainDashboard(
          lifestyle: widget.lifestyle,
          disease: widget.disease,
          medications: widget.medications,
          allergies: widget.allergies,
          goal: selectedGoal,
        ),
      ),
    );
  }

  Widget _buildGoalTile(String goal) {
    final isSelected = selectedGoal == goal;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGoal = goal;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFF0F8F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          goal,
          style: GoogleFonts.poppins(
            fontSize: 16.5,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFEFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        title: Text(
          "Your Nutrition Goal",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Choose your primary goal. We'll tailor your meal plans to match it.",
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(fontSize: 16.5, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: goalOptions.length,
                  itemBuilder: (context, index) {
                    return _buildGoalTile(goalOptions[index]);
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 3,
                ),
                child: Text(
                  "Finish Setup",
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
