// File: nutriplan-ai/mobile-app/lib/screens/onboarding/UserTypeForm.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'MedicalHistoryForm.dart';

class UserTypeForm extends StatefulWidget {
  const UserTypeForm({Key? key}) : super(key: key);

  @override
  State<UserTypeForm> createState() => _UserTypeFormState();
}

class _UserTypeFormState extends State<UserTypeForm> {
  String? selectedType;
  final List<String> userTypes = [
    "Hostel Student",
    "Gym Goer",
    "Budget-Focused Eater",
    "Office Worker / Sedentary",
    "Home-Based Person",
    "Custom"
  ];

  void _submitForm() {
    if (selectedType != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MedicalHistoryForm(
            lifestyle: selectedType!,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select your lifestyle type."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FCF9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Select Lifestyle Type",
          style: GoogleFonts.poppins(
            fontSize: 22,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Text(
              "Choose the option that best represents your daily routine. This will help us personalize your meal plans effectively.",
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: ListView.builder(
                itemCount: userTypes.length,
                itemBuilder: (context, index) {
                  final item = userTypes[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedType = item;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selectedType == item
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          color: selectedType == item
                              ? const Color(0xFFE8F5E9)
                              : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedType == item
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedType == item
                                  ? const Color(0xFF388E3C)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
              ),
              child: Text(
                "Continue",
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
