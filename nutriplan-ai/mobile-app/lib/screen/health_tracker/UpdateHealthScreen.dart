import 'package:flutter/material.dart';
import '../../components/CustomTextField.dart';
import '../../components/PrimaryButton.dart';
import '../../services/MedicalDataService.dart';
import '../../utils/Validators.dart';

class UpdateHealthScreen extends StatefulWidget {
  const UpdateHealthScreen({Key? key}) : super(key: key);

  @override
  _UpdateHealthScreenState createState() => _UpdateHealthScreenState();
}

class _UpdateHealthScreenState extends State<UpdateHealthScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _bloodPressureController = TextEditingController();
  final TextEditingController _bloodSugarController = TextEditingController();

  bool _isLoading = false;

  // Optionally, you can load existing health data here if needed.

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _bloodPressureController.dispose();
    _bloodSugarController.dispose();
    super.dispose();
  }

  Future<void> _submitHealthData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final weight = double.parse(_weightController.text.trim());
      final height = double.parse(_heightController.text.trim());
      final bloodPressure = _bloodPressureController.text.trim();
      final bloodSugar = _bloodSugarController.text.trim();

      // Send data to backend or local storage via MedicalDataService
      await MedicalDataService().updateHealthMetrics(
        weight: weight,
        height: height,
        bloodPressure: bloodPressure,
        bloodSugar: bloodSugar,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health data updated successfully!')),
      );

      Navigator.pop(context); // Go back to previous screen after update

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update health data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = double.tryParse(value);
    if (number == null || number <= 0) {
      return 'Enter a valid positive number for $fieldName';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Health Metrics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    CustomTextField(
                      controller: _weightController,
                      labelText: 'Weight (kg)',
                      keyboardType: TextInputType.number,
                      validator: (val) => _validateNumber(val, 'Weight'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _heightController,
                      labelText: 'Height (cm)',
                      keyboardType: TextInputType.number,
                      validator: (val) => _validateNumber(val, 'Height'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _bloodPressureController,
                      labelText: 'Blood Pressure (e.g., 120/80)',
                      keyboardType: TextInputType.text,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Blood Pressure is required';
                        }
                        // Basic validation pattern for BP e.g. "120/80"
                        final pattern = RegExp(r'^\d{2,3}\/\d{2,3}$');
                        if (!pattern.hasMatch(val)) {
                          return 'Enter blood pressure in format like 120/80';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _bloodSugarController,
                      labelText: 'Blood Sugar (mg/dL)',
                      keyboardType: TextInputType.number,
                      validator: (val) => _validateNumber(val, 'Blood Sugar'),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      text: 'Update',
                      onPressed: _submitHealthData,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
