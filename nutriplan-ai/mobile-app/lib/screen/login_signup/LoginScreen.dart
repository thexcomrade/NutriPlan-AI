// File: nutriplan-ai/mobile-app/lib/screens/login_signup/LoginScreen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/WelcomeScreen.dart';
import 'SignupScreen.dart';
import '../dashboard/MainDashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Login failed";
      if (e.code == 'user-not-found') {
        errorMsg = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        errorMsg = "Incorrect password.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    {required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15),
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
          if (val == null || val.isEmpty) return 'Field required';
          if (!isPassword && !val.contains('@')) return 'Enter valid email';
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
      backgroundColor: const Color(0xFFF2FCF3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Text(
                "Welcome Back 👋",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Login to access your personalized meal plans",
                style: GoogleFonts.roboto(
                  fontSize: 15.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      hint: "Email",
                      icon: Icons.email_outlined,
                      controller: _emailController,
                    ),
                    _buildTextField(
                      hint: "Password",
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                "Login",
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: GoogleFonts.poppins(color: Colors.black54),
                      children: [
                        TextSpan(
                          text: "Sign Up",
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

              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Forgot password flow
                  },
                  child: Text(
                    "Forgot Password?",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
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
