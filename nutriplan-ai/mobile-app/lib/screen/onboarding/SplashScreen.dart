// 📍 File: lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:page_transition/page_transition.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          duration: const Duration(milliseconds: 800),
          child: const Placeholder(), // TODO: Replace with LoginScreen
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildLogo() {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Column(
        children: [
          Image.asset(
            'assets/images/nutriplan_logo.png', // Replace with your logo path
            height: 120,
          ),
          const SizedBox(height: 20),
          Text(
            'NutriPlan AI',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'AI-Driven Nutrition Companion',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 40.0),
      child: SpinKitFadingCube(
        color: Colors.green,
        size: 40.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            height: screenHeight * 0.7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildLogo(),
                buildLoading(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
