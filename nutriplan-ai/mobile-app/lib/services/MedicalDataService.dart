import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutriplan_ai/models/MedicalModel.dart';

class MedicalDataService {
  final String _baseUrl = 'https://api.nutriplanai.com'; // Replace with your API
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetch user medical data
  Future<MedicalModel?> fetchMedicalHistory() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile/medical/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MedicalModel.fromJson(data);
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print("Exception in fetchMedicalHistory: $e");
    }
    return null;
  }

  /// Submit or update user medical data
  Future<bool> updateMedicalHistory(MedicalModel medicalData) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final response = await http.post(
        Uri.parse('$_baseUrl/api/profile/medical/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(medicalData.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Exception in updateMedicalHistory: $e");
      return false;
    }
  }

  /// Upload real-time health tracker stats
  Future<bool> uploadHealthStats({
    required double height,
    required double weight,
    required double bloodSugar,
    required double bloodPressure,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final response = await http.post(
        Uri.parse('$_baseUrl/api/profile/healthstats/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'height': height,
          'weight': weight,
          'bloodSugar': bloodSugar,
          'bloodPressure': bloodPressure,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Exception in uploadHealthStats: $e");
      return false;
    }
  }

  /// Fetch recent health metrics like BMI, etc.
  Future<Map<String, dynamic>?> fetchHealthStats() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile/healthstats/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to fetch stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching health stats: $e');
    }
    return null;
  }

  /// Delete user’s medical history (for account removal or reset)
  Future<bool> deleteMedicalHistory() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/profile/medical/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Exception in deleteMedicalHistory: $e");
      return false;
    }
  }
}
