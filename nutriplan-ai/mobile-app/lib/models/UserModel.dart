import 'package:flutter/foundation.dart';

/// A model representing the user profile details for NutriPlan AI.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String userType; // hostel, gym, family, budget, etc.
  final int age;
  final String gender; // male, female, other
  final double height; // in centimeters
  final double weight; // in kilograms
  final String goal; // weight_loss, weight_gain, fitness, etc.
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.userType,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.goal,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory method to create a `UserModel` from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      userType: json['userType'] ?? 'hostel',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? 'male',
      height: (json['height'] ?? 0).toDouble(),
      weight: (json['weight'] ?? 0).toDouble(),
      goal: json['goal'] ?? 'fitness',
      profileImageUrl: json['profileImageUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Converts the model to JSON format
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'goal': goal,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy of this user with updated fields
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? userType,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? goal,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goal: goal ?? this.goal,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, userType: $userType, goal: $goal)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          userType == other.userType &&
          age == other.age &&
          gender == other.gender &&
          height == other.height &&
          weight == other.weight &&
          goal == other.goal &&
          profileImageUrl == other.profileImageUrl &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      userType.hashCode ^
      age.hashCode ^
      gender.hashCode ^
      height.hashCode ^
      weight.hashCode ^
      goal.hashCode ^
      profileImageUrl.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
