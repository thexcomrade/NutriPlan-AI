import 'package:flutter/foundation.dart';

/// A model representing the user's medical profile and dietary conditions.
class MedicalModel {
  /// Unique ID for the medical record
  final String id;

  /// List of known allergies (e.g., nuts, dairy, gluten)
  final List<String> allergies;

  /// List of medical conditions (e.g., diabetes, hypertension)
  final List<String> conditions;

  /// Medications user is currently taking
  final List<String> medications;

  /// Daily calorie target recommended by a physician or based on analysis
  final int? recommendedCalories;

  /// Any dietary restrictions (e.g., vegan, low-sodium)
  final List<String> dietaryRestrictions;

  /// Whether the user is on any special diet (e.g., keto, intermittent fasting)
  final String? specialDiet;

  /// Optional physician or healthcare contact info
  final String? physicianContact;

  /// Timestamp of last update
  final DateTime updatedAt;

  MedicalModel({
    required this.id,
    required this.allergies,
    required this.conditions,
    required this.medications,
    this.recommendedCalories,
    required this.dietaryRestrictions,
    this.specialDiet,
    this.physicianContact,
    required this.updatedAt,
  });

  /// Creates a new instance from a JSON object
  factory MedicalModel.fromJson(Map<String, dynamic> json) {
    return MedicalModel(
      id: json['id'] ?? '',
      allergies: List<String>.from(json['allergies'] ?? []),
      conditions: List<String>.from(json['conditions'] ?? []),
      medications: List<String>.from(json['medications'] ?? []),
      recommendedCalories: json['recommendedCalories'],
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
      specialDiet: json['specialDiet'],
      physicianContact: json['physicianContact'],
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Converts the instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'allergies': allergies,
      'conditions': conditions,
      'medications': medications,
      'recommendedCalories': recommendedCalories,
      'dietaryRestrictions': dietaryRestrictions,
      'specialDiet': specialDiet,
      'physicianContact': physicianContact,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this model with optional overrides
  MedicalModel copyWith({
    String? id,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? medications,
    int? recommendedCalories,
    List<String>? dietaryRestrictions,
    String? specialDiet,
    String? physicianContact,
    DateTime? updatedAt,
  }) {
    return MedicalModel(
      id: id ?? this.id,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      recommendedCalories: recommendedCalories ?? this.recommendedCalories,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      specialDiet: specialDiet ?? this.specialDiet,
      physicianContact: physicianContact ?? this.physicianContact,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MedicalModel(id: $id, conditions: $conditions, allergies: $allergies, medications: $medications, dietaryRestrictions: $dietaryRestrictions)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicalModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listEquals(allergies, other.allergies) &&
          listEquals(conditions, other.conditions) &&
          listEquals(medications, other.medications) &&
          recommendedCalories == other.recommendedCalories &&
          listEquals(dietaryRestrictions, other.dietaryRestrictions) &&
          specialDiet == other.specialDiet &&
          physicianContact == other.physicianContact &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      allergies.hashCode ^
      conditions.hashCode ^
      medications.hashCode ^
      recommendedCalories.hashCode ^
      dietaryRestrictions.hashCode ^
      specialDiet.hashCode ^
      physicianContact.hashCode ^
      updatedAt.hashCode;
}
