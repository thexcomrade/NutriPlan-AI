// 📍 File: lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  String selectedGoal = 'Muscle Gain';
  final List<String> goals = ['Muscle Gain', 'Weight Loss', 'Balanced', 'Diabetic Friendly'];
  List<String> diseases = ['Diabetes', 'Hypertension'];
  List<String> medications = ['Metformin', 'Atorvastatin'];

  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();

  void _addDisease() {
    if (_diseaseController.text.trim().isNotEmpty) {
      setState(() {
        diseases.add(_diseaseController.text.trim());
        _diseaseController.clear();
      });
    }
  }

  void _addMedication() {
    if (_medicationController.text.trim().isNotEmpty) {
      setState(() {
        medications.add(_medicationController.text.trim());
        _medicationController.clear();
      });
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.green.shade800),
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, Widget? trailing}) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green.shade700),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16)),
        trailing: trailing,
      ),
    );
  }

  Widget _buildChipsSection(List<String> items, Function(int) onDelete) {
    return Wrap(
      spacing: 8,
      children: List.generate(items.length, (index) {
        return Chip(
          label: Text(items[index], style: GoogleFonts.poppins()),
          backgroundColor: Colors.green.shade100,
          deleteIcon: const Icon(Icons.close),
          onDeleted: () => onDelete(index),
        );
      }),
    );
  }

  Widget _buildAddInput({required String label, required TextEditingController controller, required VoidCallback onAdd}) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.poppins(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )
      ],
    );
  }

  void _logoutUser() {
    // Replace with actual logout logic
    Navigator.pop(context);
  }

  void _deleteAccount() {
    // Confirm deletion
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete your account? This action is irreversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              // Perform account deletion
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Dietary Goal"),
            _buildListTile(
              icon: FontAwesomeIcons.utensils,
              title: "Current Goal",
              trailing: DropdownButton<String>(
                value: selectedGoal,
                items: goals.map((goal) {
                  return DropdownMenuItem(
                    value: goal,
                    child: Text(goal, style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedGoal = val!),
              ),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("Medical Info"),

            _buildAddInput(label: "Add Disease", controller: _diseaseController, onAdd: _addDisease),
            const SizedBox(height: 10),
            _buildChipsSection(diseases, (index) {
              setState(() => diseases.removeAt(index));
            }),

            const SizedBox(height: 20),
            _buildAddInput(label: "Add Medication", controller: _medicationController, onAdd: _addMedication),
            const SizedBox(height: 10),
            _buildChipsSection(medications, (index) {
              setState(() => medications.removeAt(index));
            }),

            const SizedBox(height: 20),
            _buildSectionTitle("Preferences"),
            _buildListTile(
              icon: FontAwesomeIcons.bell,
              title: "Notifications",
              trailing: Switch(
                value: notificationsEnabled,
                onChanged: (val) => setState(() => notificationsEnabled = val),
              ),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("Account"),
            _buildListTile(
              icon: Icons.logout,
              title: "Logout",
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _logoutUser,
              ),
            ),
            _buildListTile(
              icon: Icons.delete_forever,
              title: "Delete Account",
              trailing: IconButton(
                icon: const Icon(Icons.warning, color: Colors.red),
                onPressed: _deleteAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
