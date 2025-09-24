import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _classeController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();
  
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureDeletePassword = true;
  String? _selectedGender;
  String _originalEmail = '';
  
  FluttermojiController? _fluttermojiController;
  
  // Replace with your actual Symfony server URL
  static const String _baseUrl = 'http://127.0.0.1:8001';

  @override
  void initState() {
    super.initState();
    _initializeFluttermoji();
    _loadProfile();
    _selectedGender = null;
  }

  @override
  void didChangeDependencies() {



    
    super.didChangeDependencies();
    _refreshAvatar();
  }

  Future<void> _initializeFluttermoji() async {
    try {
      _fluttermojiController = Get.find<FluttermojiController>();
    } catch (e) {
      _fluttermojiController = Get.put(FluttermojiController(), permanent: true);
    }
    
    if (_fluttermojiController != null) {
      await _fluttermojiController!.setFluttermoji();
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshAvatar() {
    _initializeFluttermoji();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstNameController.text = prefs.getString('profile_firstname') ?? '';
      _lastNameController.text = prefs.getString('profile_lastname') ?? '';
      _emailController.text = prefs.getString('profile_email') ?? '';
      _originalEmail = prefs.getString('profile_email') ?? '';
final gender = prefs.getString('profile_gender');
if (gender == 'Male' || gender == 'Female' || gender == 'Other') {
  _selectedGender = gender;
} else {
  _selectedGender = null;
}
      _classeController.text = prefs.getString('profile_classe') ?? '';
      
      // Set new email to current email initially
      _newEmailController.text = _emailController.text;
    });
  }

  Future<void> _updateProfile() async {
    if (_firstNameController.text.trim().isEmpty || 
        _lastNameController.text.trim().isEmpty ||
        _newEmailController.text.trim().isEmpty) {
      _showErrorDialog('Please fill in all required fields');
      return;
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_newEmailController.text.trim())) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    // If changing password, validate password fields
    if (_currentPasswordController.text.isNotEmpty || _newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        _showErrorDialog('Please enter your current password');
        return;
      }
      if (_newPasswordController.text.length < 6) {
        _showErrorDialog('New password must be at least 6 characters');
        return;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        _showErrorDialog('New passwords do not match');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'email': _originalEmail, // Current email to identify user
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'sexe': _selectedGender,
        'classe': _classeController.text.trim(),
        'new_email': _newEmailController.text.trim(),
      };

      // Add password change if provided
      if (_currentPasswordController.text.isNotEmpty && _newPasswordController.text.isNotEmpty) {
        updateData['current_password'] = _currentPasswordController.text;
        updateData['new_password'] = _newPasswordController.text;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final userData = responseData['user'];
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_email', userData['email'] ?? '');
        await prefs.setString('profile_firstname', userData['firstname'] ?? '');
        await prefs.setString('profile_lastname', userData['lastname'] ?? '');
        await prefs.setString('profile_name', '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}');
        await prefs.setString('profile_gender', userData['sexe'] ?? '');
        await prefs.setString('profile_classe', userData['classe'] ?? '');
        
        // Update original email reference
        _originalEmail = userData['email'] ?? '';
        
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Update failed';
        
        switch (response.statusCode) {
          case 400:
            errorMessage = errorData['error'] ?? 'Invalid data provided';
            break;
          case 401:
            errorMessage = 'Current password is incorrect';
            break;
          case 404:
            errorMessage = 'User not found';
            break;
          case 409:
            errorMessage = 'Email already in use';
            break;
          default:
            errorMessage = errorData['error'] ?? 'An unexpected error occurred';
        }
        
        if (mounted) {
          _showErrorDialog(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Network error. Please check your connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog first
    bool confirmed = await _showDeleteConfirmDialog();
    if (!confirmed) return;

    if (_deletePasswordController.text.isEmpty) {
      _showErrorDialog('Please enter your password to confirm deletion');
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final deleteData = {
        'email': _originalEmail,
        'password': _deletePasswordController.text,
      };

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/profile/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(deleteData),
      );

      if (response.statusCode == 200) {
        // Clear all local data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to login screen and clear navigation stack
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to delete account';
        
        switch (response.statusCode) {
          case 401:
            errorMessage = 'Incorrect password';
            break;
          case 404:
            errorMessage = 'User not found';
            break;
          default:
            errorMessage = errorData['error'] ?? 'An unexpected error occurred';
        }
        
        if (mounted) {
          _showErrorDialog(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Network error. Please check your connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
        _deletePasswordController.clear();
      }
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete Account'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deletePasswordController,
                obscureText: _obscureDeletePassword,
                decoration: InputDecoration(
                  labelText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureDeletePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureDeletePassword = !_obscureDeletePassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _deletePasswordController.clear();
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isDeleting ? null : () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: _isDeleting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Delete Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/avatar-maker');
              _refreshAvatar();
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Avatar',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE5E5),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar section
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD32F2F),
                    width: 3,
                  ),
                ),
                child: _fluttermojiController != null 
                  ? FluttermojiCircleAvatar(
                      backgroundColor: const Color(0xFFFFE5E5),
                      radius: 60,
                    )
                  : CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFFFE5E5),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
              ),
              const SizedBox(height: 16),
              
              // Edit Avatar Button
              TextButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/avatar-maker');
                  _refreshAvatar();
                },
                icon: const Icon(Icons.edit, size: 20),
                label: const Text(
                  'Edit Avatar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Profile Form
              _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person_outline,
                required: true,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_outline,
                required: true,
              ),
              const SizedBox(height: 16),
              
              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value ;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _classeController,
                label: 'Class',
                icon: Icons.school,
                required: true,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _newEmailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                required: true,
              ),
              const SizedBox(height: 32),
              
              // Password Change Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change Password (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      obscureText: _obscureCurrentPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      obscureText: _obscureNewPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      obscureText: _obscureConfirmPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Update Profile Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Update Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Delete Account Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.red,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: onToggleVisibility,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _newEmailController.dispose();
    _classeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }
}