// File: nutriplan-ai/mobile-app/lib/screens/onboarding/MedicalHistoryForm.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'NutritionGoalForm.dart';

class MedicalHistoryForm extends StatefulWidget {
  final String lifestyle;

  const MedicalHistoryForm({Key? key, required this.lifestyle}) : super(key: key);

  @override
  State<MedicalHistoryForm> createState() => _MedicalHistoryFormState();
}

class _MedicalHistoryFormState extends State<MedicalHistoryForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NutritionGoalForm(
            lifestyle: widget.lifestyle,
            disease: _diseaseController.text.trim(),
            medications: _medicationsController.text.trim(),
            allergies: _allergiesController.text.trim(),
          ),
        ),
      );
    }
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData icon = Icons.health_and_safety,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.poppins(fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(),
          hintStyle: GoogleFonts.roboto(color: Colors.black45),
          filled: true,
          fillColor: const Color(0xFFF0F8F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.green.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.green, width: 1.8),
          ),
        ),
        validator: (value) => null, // Optional fields
        maxLines: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFEFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: Text(
          "Medical Information",
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
          child: ListView(
            children: [
              Text(
                "This data helps us avoid foods that may interfere with your health or medicines.",
                style: GoogleFonts.roboto(fontSize: 16.5, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              _buildInputField(
                label: "Diseases",
                hint: "e.g. Diabetes, Hypertension, PCOS...",
                controller: _diseaseController,
                icon: Icons.medical_information,
              ),
              _buildInputField(
                label: "Medications",
                hint: "e.g. Metformin, Thyroxine...",
                controller: _medicationsController,
                icon: Icons.medication,
              ),
              _buildInputField(
                label: "Allergies",
                hint: "e.g. Gluten, Dairy, Nuts...",
                controller: _allergiesController,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 16),
                  elevation: 4,
                ),
                child: Text(
                  "Next",
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
