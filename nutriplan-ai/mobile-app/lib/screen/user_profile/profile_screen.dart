// 📍 File: lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // User Fields
  String _name = '';
  int _age = 18;
  String _gender = 'Male';
  String _lifestyle = 'Hosteler';
  final List<String> _conditions = [];
  final List<String> _medications = [];

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();

  List<String> lifestyleOptions = ['Hosteler', 'Gym Goer', 'Office Worker', 'Student', 'Senior'];
  List<String> genderOptions = ['Male', 'Female', 'Other'];

  void _submitProfile() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Simulate backend save
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      // You can call your backend API here
    }
  }

  void _addToList(String value, List<String> list, TextEditingController controller) {
    if (value.trim().isNotEmpty && !list.contains(value.trim())) {
      setState(() => list.add(value.trim()));
      controller.clear();
    }
  }

  void _removeFromList(String value, List<String> list) {
    setState(() => list.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField("Full Name", _nameController, (val) => _name = val!),
                const SizedBox(height: 16),
                _buildNumberField("Age", (val) => _age = int.parse(val!)),
                const SizedBox(height: 16),
                _buildDropdown("Gender", _gender, genderOptions, (val) {
                  setState(() => _gender = val!);
                }),
                const SizedBox(height: 16),
                _buildDropdown("Lifestyle", _lifestyle, lifestyleOptions, (val) {
                  setState(() => _lifestyle = val!);
                }),
                const SizedBox(height: 24),
                _buildTagInput("Health Conditions (e.g., Diabetes)", _conditionController, _conditions),
                const SizedBox(height: 16),
                _buildTagInput("Medications (e.g., Metformin)", _medicationController, _medications),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitProfile,
                    child: Text(
                      "Save Profile",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Function(String?) onSaved) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (val) => val!.isEmpty ? 'Required' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildNumberField(String label, Function(String?) onSaved) {
    return TextFormField(
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (val) => val!.isEmpty || int.tryParse(val) == null ? 'Enter valid number' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildDropdown(String label, String currentValue, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      style: GoogleFonts.poppins(color: Colors.black87),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTagInput(String label, TextEditingController controller, List<String> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Add item",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (val) => _addToList(val, list, controller),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _addToList(controller.text, list, controller),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: list.map((item) {
            return Chip(
              label: Text(item, style: GoogleFonts.poppins(fontSize: 13)),
              backgroundColor: Colors.green.shade100,
              onDeleted: () => _removeFromList(item, list),
            );
          }).toList(),
        ),
      ],
    );
  }
}
