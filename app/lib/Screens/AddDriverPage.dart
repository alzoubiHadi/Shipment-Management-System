import 'package:flutter/material.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Driver.dart';

class AddDriverPage extends StatefulWidget {
  final Function(Driver)? onSubmit;
  final Driver? driver; // Optional driver for editing

  const AddDriverPage({
    super.key,
    this.onSubmit,
    this.driver,
  });

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _ageController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  final _licenseExpiryController = TextEditingController();

  final _passwordController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill form if editing an existing driver
    if (widget.driver != null) {
      final d = widget.driver!;
      _nameController.text = d.name ?? '';
      _emailController.text = d.email ?? '';
      _phoneController.text = d.phone ?? '';
      _nationalityController.text = d.nationality ?? '';
      _ageController.text = d.age ?? '';
      _driverLicenseController.text = d.driver_license ?? '';
      _licenseExpiryController.text = d.license_expiry ?? '';
      // We intentionally leave the password blank for security reasons
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _ageController.dispose();
    _driverLicenseController.dispose();
    _licenseExpiryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final driver = Driver(
      id: widget.driver?.id ?? '', // Keep the same ID if editing
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      // Trucks are no longer tied to a driver record directly — a driver
      // adds their own trucks later from "My Trucks", since a truck can
      // change hands over time.
      truck_number: '',
      truck_type: '',
      nationality: _nationalityController.text.trim(),
      age: _ageController.text.trim(),
      driver_license: _driverLicenseController.text.trim(),
      license_expiry: _licenseExpiryController.text.trim(),
      password: _passwordController.text, user_id: '',
    );

    try {
      if (widget.driver != null) {
        // Update existing driver
        await DriverService.updateDriver(driver);
      } else {
        // Create new driver
        await DriverService.createDriver(driver);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.driver != null ? 'Driver updated successfully' : 'Driver created successfully'),
        ),
      );

      widget.onSubmit?.call(driver);

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickLicenseDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.bg,
              surface: AppColors.surface,
              onSurface: AppColors.cream,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      _licenseExpiryController.text =
      "${pickedDate.year.toString().padLeft(4, '0')}-"
          "${pickedDate.month.toString().padLeft(2, '0')}-"
          "${pickedDate.day.toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.driver != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: AppColors.cream,
        ),
        title: Text(
          isEditing ? 'Edit Driver' : 'Add Driver',
          style: const TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              children: [
                _buildField(
                  controller: _nameController,
                  label: 'Name',
                  icon: Icons.person,
                ),
                _buildField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildField(
                  controller: _phoneController,
                  label: 'Phone',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                _buildField(
                  controller: _nationalityController,
                  label: 'Nationality',
                  icon: Icons.flag,
                ),
                _buildField(
                  controller: _ageController,
                  label: 'Age',
                  icon: Icons.cake,
                  keyboardType: TextInputType.number,
                ),
                _buildField(
                  controller: _driverLicenseController,
                  label: 'Driver License',
                  icon: Icons.badge,
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: _licenseExpiryController,
                    readOnly: true,
                    style: const TextStyle(
                      color: AppColors.cream,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'License Expiry is required';
                      }
                      return null;
                    },
                    onTap: _pickLicenseDate,
                    decoration: InputDecoration(
                      labelText: 'License Expiry',
                      labelStyle: const TextStyle(
                        color: AppColors.muted,
                      ),
                      prefixIcon: const Icon(
                        Icons.calendar_today,
                        color: AppColors.gold,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.gold,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),



                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      color: AppColors.cream,
                    ),
                    validator: (value) {
                      // Only require password if creating a new driver
                      if (!isEditing && (value == null || value.trim().isEmpty)) {
                        return 'Password is required';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: isEditing ? 'Password (leave blank to keep current)' : 'Password',
                      labelStyle: const TextStyle(
                        color: AppColors.muted,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock,
                        color: AppColors.gold,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.gold,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.gold,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveDriver,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Saving...' : (isEditing ? 'Update Driver' : 'Save Driver'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: AppColors.cream,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.muted,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.gold,
          ),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.gold,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}