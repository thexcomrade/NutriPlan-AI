import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// NutriPlan AI - Medical Safety Check Screen
/// Integrates theme toggling, animations, AI chat, meal viewer,
/// and real-time validations.
/// Author: NutriPlan AI Team | 2025

// Theme Provider for toggling dark/light mode
class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

class MedSafetyCheck extends StatefulWidget {
  @override
  _MedSafetyCheckState createState() => _MedSafetyCheckState();
}

class _MedSafetyCheckState extends State<MedSafetyCheck>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _medicineController = TextEditingController();
  final _allergyController = TextEditingController();
  final _notesController = TextEditingController();

  bool _checkingSafety = false;
  String _safetyResult = "";
  String _error = "";

  // Animation Controller for smooth fade-in of results
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Mock meal plans data
  final List<Map<String, String>> _mealPlans = [
    {
      "title": "Low Sodium Salad",
      "description": "Fresh greens with minimal salt, safe for hypertension.",
      "image": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c"
    },
    {
      "title": "Diabetic Friendly Dinner",
      "description":
          "Grilled chicken with veggies, designed for blood sugar control.",
      "image": "https://images.unsplash.com/photo-1504674900247-0877df9cc836"
    },
    {
      "title": "High Protein Breakfast",
      "description": "Oats with almond butter and chia seeds for muscle gain.",
      "image": "https://images.unsplash.com/photo-1513104890138-7c749659a591"
    },
  ];

  // Chat messages state
  final List<_ChatMessage> _messages = [];
  final _chatController = TextEditingController();
  bool _chatLoading = false;

  @override
  void initState() {
    super.initState();
    // Animation for fade in/out
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);

    // Add a welcome bot message on load
    _messages.add(_ChatMessage(
        message:
            "Hi! Ask me anything about your medicines or dietary safety.",
        fromUser: false));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _medicineController.dispose();
    _allergyController.dispose();
    _notesController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  /// Validates medicine name (basic, non-empty)
  String? _validateMedicine(String? val) {
    if (val == null || val.trim().isEmpty) {
      return "Please enter the medicine name";
    }
    if (val.trim().length < 2) return "Medicine name too short";
    return null;
  }

  /// Validates allergy input (optional but if present, min length)
  String? _validateAllergy(String? val) {
    if (val != null && val.trim().isNotEmpty && val.trim().length < 3) {
      return "Allergy input too short";
    }
    return null;
  }

  /// Simulated async API call to check medical safety
  Future<String> _checkMedicalSafety(
      String medicine, String allergy, String notes) async {
    // For demo, we simulate logic:
    await Future.delayed(Duration(seconds: 2));

    final lowRiskMeds = ["paracetamol", "ibuprofen", "aspirin"];
    final riskyMeds = ["warfarin", "lithium", "amiodarone"];
    final medLower = medicine.toLowerCase().trim();

    if (riskyMeds.contains(medLower)) {
      return
          "⚠️ Warning: $medicine can have serious side effects or interactions. Please consult your doctor before use.";
    } else if (lowRiskMeds.contains(medLower)) {
      return "✅ $medicine is generally safe but monitor for allergies.";
    } else {
      return
          "ℹ️ $medicine safety data is not available. Please consult a healthcare professional.";
    }
  }

  /// Triggered when user submits safety check form
  void _onCheckSafety() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _checkingSafety = true;
      _safetyResult = "";
      _error = "";
    });

    _animationController.reset();

    try {
      final result = await _checkMedicalSafety(
          _medicineController.text, _allergyController.text, _notesController.text);

      setState(() {
        _safetyResult = result;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = "Failed to check safety: ${e.toString()}";
      });
    } finally {
      setState(() {
        _checkingSafety = false;
      });
    }
  }

  /// Handles sending a chat message & receiving AI response (mocked)
  void _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(message: text, fromUser: true));
      _chatLoading = true;
      _chatController.clear();
    });

    // Simulated AI reply delay & simple keyword-based reply
    await Future.delayed(Duration(seconds: 2));

    String reply;
    if (text.toLowerCase().contains("protein")) {
      reply = "For more protein, try lentils, eggs, or Greek yogurt.";
    } else if (text.toLowerCase().contains("side effect")) {
      reply =
          "Side effects vary by medicine. Always consult your physician.";
    } else {
      reply =
          "I'm here to help with your dietary and medicine safety questions!";
    }

    setState(() {
      _messages.add(_ChatMessage(message: reply, fromUser: false));
      _chatLoading = false;
    });
  }

  /// Builds the Meal Viewer widget with smooth fade and cards
  Widget _buildMealViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recommended Meal Plans",
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _mealPlans.length,
            itemBuilder: (context, index) {
              final meal = _mealPlans[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 400),
                margin: EdgeInsets.only(right: 16),
                width: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                  image: DecorationImage(
                    image: NetworkImage(meal["image"]!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.25),
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal["title"]!,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
                        meal["description"]!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  /// Builds the AI Chat interface
  Widget _buildChatInterface() {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                return Align(
                  alignment:
                      msg.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    decoration: BoxDecoration(
                      color: msg.fromUser
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft:
                            msg.fromUser ? Radius.circular(18) : Radius.circular(0),
                        bottomRight:
                            msg.fromUser ? Radius.circular(0) : Radius.circular(18),
                      ),
                    ),
                    child: Text(
                      msg.message,
                      style: GoogleFonts.poppins(
                        color: msg.fromUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_chatLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SpinKitThreeBounce(
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(bottom: 4, left: 8, right: 8, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (_) => _sendChatMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask your AI Dietician...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _chatLoading ? null : _sendChatMessage,
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(12),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  child: Icon(Icons.send, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Medical Safety Check",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
            icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round),
            onPressed: () => themeNotifier.toggleTheme(),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Medicine Safety Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enter Medicine & Allergy Details",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _medicineController,
                      decoration: InputDecoration(
                        labelText: "Medicine Name",
                        prefixIcon: Icon(Icons.medication),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validateMedicine,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _allergyController,
                      decoration: InputDecoration(
                        labelText: "Known Allergies (Optional)",
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validateAllergy,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Additional Notes",
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _checkingSafety
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ))
                            : Icon(Icons.health_and_safety),
                        label: Text(_checkingSafety ? "Checking..." : "Check Safety"),
                        onPressed: _checkingSafety ? null : _onCheckSafety,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Safety Result with fade animation
              SizeTransition(
                sizeFactor: _fadeAnimation,
                axisAlignment: -1.0,
                child: _safetyResult.isNotEmpty
                    ? Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _safetyResult.startsWith("⚠️")
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _safetyResult,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _safetyResult.startsWith("⚠️")
                                ? Colors.red.shade700
                                : Colors.green.shade800,
                          ),
                        ),
                      )
                    : SizedBox.shrink(),
              ),

              if (_error.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),

              SizedBox(height: 16),

              // Meal Viewer Section
              _buildMealViewer(),

              SizedBox(height: 16),

              // AI Chat Interface
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: _buildChatInterface(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat Message Model class
class _ChatMessage {
  final String message;
  final bool fromUser;
  _ChatMessage({required this.message, required this.fromUser});
}
