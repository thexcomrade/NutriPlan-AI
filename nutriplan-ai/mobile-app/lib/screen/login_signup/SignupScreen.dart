// File: nutriplan-ai/mobile-app/lib/screens/login_signup/SignupScreen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/UserTypeForm.dart';
import 'LoginScreen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _signupUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserTypeForm()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Signup failed. Try again.";
      if (e.code == 'email-already-in-use') {
        msg = "Email is already registered.";
      } else if (e.code == 'weak-password') {
        msg = "Use a stronger password (min 6 chars).";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _inputField({
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    IconData icon = Icons.person,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        validator: (val) {
          if (val == null || val.isEmpty) return 'This field is required';
          if (!isPassword && !val.contains('@')) return 'Enter a valid email';
          if (isPassword && val.length < 6) return 'Min 6 characters';
          return null;
        },
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.green.shade600),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FFF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Text(
                "Create Account ✨",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Join NutriPlan AI and personalize your diet journey!",
                style: GoogleFonts.roboto(fontSize: 15.5, color: Colors.black54),
              ),
              const SizedBox(height: 30),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _inputField(
                      hint: "Email",
                      controller: _emailController,
                      icon: Icons.email_outlined,
                    ),
                    _inputField(
                      hint: "Password",
                      controller: _passwordController,
                      isPassword: true,
                      icon: Icons.lock_outline,
                    ),
                    _inputField(
                      hint: "Confirm Password",
                      controller: _confirmController,
                      isPassword: true,
                      icon: Icons.lock_reset_outlined,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _signupUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                "Sign Up",
                                style: GoogleFonts.poppins(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: GoogleFonts.poppins(color: Colors.black54),
                      children: [
                        TextSpan(
                          text: "Login",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
