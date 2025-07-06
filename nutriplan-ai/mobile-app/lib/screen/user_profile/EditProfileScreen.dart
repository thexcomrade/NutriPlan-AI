import 'package:flutter/material.dart';
import '../../components/CustomTextField.dart';
import '../../components/PrimaryButton.dart';
import '../../models/UserModel.dart';
import '../../services/AuthService.dart';
import '../../utils/Validators.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const EditProfileScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _emailController = TextEditingController(text: widget.currentUser.email);
    _ageController = TextEditingController(text: widget.currentUser.age?.toString() ?? '');
    _weightController = TextEditingController(text: widget.currentUser.weight?.toString() ?? '');
    _heightController = TextEditingController(text: widget.currentUser.height?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    UserModel updatedUser = widget.currentUser.copyWith(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      height: double.tryParse(_heightController.text.trim()),
    );

    try {
      await AuthService().updateUserProfile(updatedUser);
      setState(() {
        _successMessage = "Profile updated successfully!";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update profile: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          CustomTextField(
            controller: _nameController,
            labelText: 'Full Name',
            validator: Validators.requiredField,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            labelText: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.emailValidator,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _ageController,
            labelText: 'Age',
            keyboardType: TextInputType.number,
            validator: Validators.numberValidator,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _weightController,
            labelText: 'Weight (kg)',
            keyboardType: TextInputType.number,
            validator: Validators.numberValidator,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _heightController,
            labelText: 'Height (cm)',
            keyboardType: TextInputType.number,
            validator: Validators.numberValidator,
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_successMessage != null)
            Text(
              _successMessage!,
              style: const TextStyle(color: Colors.green),
            ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Save Changes',
            onPressed: _saveProfile,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(child: _buildProfileForm()),
      ),
    );
  }
}
