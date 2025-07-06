// 📄 D:\nutriplan-ai\mobile-app\lib\utils\SharedPrefsUtil.dart

import 'package:shared_preferences/shared_preferences.dart';

/// A powerful utility for managing local storage (persistent key-value).
class SharedPrefsUtil {
  static SharedPreferences? _prefs;

  /// Initializes the shared preferences instance
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save a string value
  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Get a string value
  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Save a boolean value
  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Get a boolean value
  static bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  /// Save an integer value
  static Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// Get an integer value
  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Save a double value
  static Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  /// Get a double value
  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  /// Remove a key
  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  /// Clear all stored keys and values
  static Future<void> clear() async {
    await _prefs?.clear();
  }

  /// Check if a key exists
  static bool contains(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  /// Save user login state
  static Future<void> setLoggedIn(bool value) async {
    await setBool('isLoggedIn', value);
  }

  /// Get user login state
  static bool isLoggedIn() {
    return getBool('isLoggedIn');
  }

  /// Save auth token
  static Future<void> setToken(String token) async {
    await setString('authToken', token);
  }

  /// Get auth token
  static String? getToken() {
    return getString('authToken');
  }

  /// Save user type (e.g., gym-goer, hosteler)
  static Future<void> setUserType(String userType) async {
    await setString('userType', userType);
  }

  /// Get user type
  static String? getUserType() {
    return getString('userType');
  }

  /// Save onboarding completion status
  static Future<void> setOnboardingComplete(bool value) async {
    await setBool('onboardingComplete', value);
  }

  /// Get onboarding completion status
  static bool isOnboardingComplete() {
    return getBool('onboardingComplete');
  }
}
