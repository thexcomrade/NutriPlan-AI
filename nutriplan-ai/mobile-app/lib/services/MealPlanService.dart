import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nutriplan_ai/models/MealPlanModel.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealPlanService {
  final String _baseUrl = 'https://api.nutriplanai.com'; // Replace with your actual API endpoint
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetches personalized meal plan for the current user
  Future<MealPlanModel?> fetchMealPlan() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await http.get(
        Uri.parse('$_baseUrl/api/mealplan/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MealPlanModel.fromJson(data);
      } else {
        print('Failed to fetch meal plan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchMealPlan: $e');
    }
    return null;
  }

  /// Updates the user's meal preferences
  Future<bool> updateMealPreferences(Map<String, dynamic> preferences) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await http.put(
        Uri.parse('$_baseUrl/api/mealplan/preferences/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(preferences),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error in updateMealPreferences: $e');
      return false;
    }
  }

  /// Fetches detailed info of a single meal by ID
  Future<Map<String, dynamic>?> fetchMealDetails(String mealId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mealplan/detail/$mealId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to fetch meal details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchMealDetails: $e');
    }
    return null;
  }

  /// Re-generates a new meal plan based on current user profile
  Future<MealPlanModel?> regenerateMealPlan() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await http.post(
        Uri.parse('$_baseUrl/api/mealplan/regenerate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"uid": user.uid}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MealPlanModel.fromJson(data);
      } else {
        print('Failed to regenerate meal plan: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in regenerateMealPlan: $e');
    }
    return null;
  }

  /// Saves a user's feedback for a specific meal
  Future<bool> submitMealFeedback(String mealId, String feedback) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await http.post(
        Uri.parse('$_baseUrl/api/mealplan/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': user.uid,
          'mealId': mealId,
          'feedback': feedback,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error in submitMealFeedback: $e');
      return false;
    }
  }
}
