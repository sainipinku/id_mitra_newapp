import 'package:flutter/material.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class AddCorporateFormPage extends StatefulWidget {
  final Map<String, String>? editCorporate;

  const AddCorporateFormPage({super.key, this.editCorporate});

  @override
  State<AddCorporateFormPage> createState() => _AddCorporateFormPageState();
}

class _AddCorporateFormPageState extends State<AddCorporateFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPhoneController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.editCorporate != null) {
      _companyNameController.text = widget.editCorporate!['name'] ?? '';
      _addressController.text = widget.editCorporate!['address'] ?? '';
      _companyCodeController.text = "CORP001";
      _websiteController.text = "https://example.com";
      _emailController.text = "corporate@example.com";
      _phoneController.text = "9876543210";
      _adminNameController.text = "John Doe";
      _adminEmailController.text = "admin@example.com";
      _adminPhoneController.text = "9988776655";
      _employeeIdController.text = "EMP123";
    }
    if (widget.editCorporate == null) {
      _employeeIdController.text = "partner@gmail.com";
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyCodeController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: widget.editCorporate != null ? 'Edit Corporate' : 'Add New Corporate',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Corporate Details'),
              const SizedBox(height: 15),
              _buildCorporateDetailsFields(),
              const SizedBox(height: 25),
              _buildSectionTitle('Administrator Account'),
              const SizedBox(height: 10),
              Text(
                'This will create an admin account with full permissions for the corporate.',
                style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
              ),
              const SizedBox(height: 15),
              _buildAdminAccountFields(),
              const SizedBox(height: 30),
              AppButton(
                title: widget.editCorporate != null ? 'Update Corporate' : 'Create Corporate',
                color: AppTheme.btnColor,
                onTap: _submitForm,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: MyStyles.boldText(size: 18, color: AppTheme.black_Color),
    );
  }

  Widget _buildCorporateDetailsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Company Name *'),
        AppTextField(
          controller: _companyNameController,
          hintText: 'Enter company name',
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Company Code *'),
                  AppTextField(
                    controller: _companyCodeController,
                    hintText: 'e.g. ABCD',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Website'),
                  AppTextField(
                    controller: _websiteController,
                    hintText: 'https://example.com',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Email *'),
                  AppTextField(
                    controller: _emailController,
                    hintText: 'company@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Phone *'),
                  AppTextField(
                    controller: _phoneController,
                    hintText: 'Phone number',
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildFieldLabel('Address'),
        AppTextField(
          controller: _addressController,
          hintText: 'Company address',
          mxLine: 3,
        ),
      ],
    );
  }

  Widget _buildAdminAccountFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Admin Name *'),
        AppTextField(
          controller: _adminNameController,
          hintText: 'Full name',
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Admin Email *'),
                  AppTextField(
                    controller: _adminEmailController,
                    hintText: 'admin@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Admin Phone *'),
                  AppTextField(
                    controller: _adminPhoneController,
                    hintText: 'Phone number',
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Employee ID'),
                  AppTextField(
                    controller: _employeeIdController,
                    hintText: 'Employee ID',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Password *'),
                  AppTextField(
                    controller: _passwordController,
                    hintText: '........',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: AppTheme.graySubTitleColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildFieldLabel('Confirm Password *'),
        AppTextField(
          controller: _confirmPasswordController,
          hintText: '........',
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: AppTheme.graySubTitleColor,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          validator: (v) {
            if (v!.isEmpty) return 'Required';
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: MyStyles.mediumText(size: 14, color: AppTheme.black_Color),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final corporateData = {
        'name': _companyNameController.text,
        'address': _addressController.text,
        'date': DateTime.now().toString(), // Just dummy date
        'status': widget.editCorporate != null ? widget.editCorporate!['status']! : '1',
        'logo': widget.editCorporate != null ? widget.editCorporate!['logo']! : 'https://via.placeholder.com/150',
      };
      Navigator.pop(context, corporateData);
    }
  }
}
