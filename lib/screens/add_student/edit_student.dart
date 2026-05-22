import 'dart:io';

import 'package:flutter/material.dart';
import 'package:idmitra/Widgets/AppTextStyles.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:image_picker/image_picker.dart';

class EditStudent extends StatefulWidget {
  final StudentDetailsData student;

  const EditStudent({super.key, required this.student});

  @override
  State<EditStudent> createState() => _EditStudentState();
}

class _EditStudentState extends State<EditStudent> {
  late final TextEditingController studentNameController;
  late final TextEditingController classController;
  late final TextEditingController sectionController;
  late final TextEditingController rollNumberController;
  late final TextEditingController phoneNumberController;
  late final TextEditingController parentsNameController;
  late final TextEditingController parentsPhoneController;

  File? studentImageFile;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    studentNameController = TextEditingController(text: widget.student.name ?? '');
    classController = TextEditingController(text: widget.student.datumClass?.name ?? '');
    sectionController = TextEditingController(text: widget.student.section?.name ?? '');
    rollNumberController = TextEditingController(text: widget.student.rollNo?.toString() ?? '');
    phoneNumberController = TextEditingController(text: widget.student.phone?.toString() ?? '');
    parentsNameController = TextEditingController(text: widget.student.fatherName ?? '');
    parentsPhoneController = TextEditingController(text: widget.student.fatherPhone ?? '');
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        studentImageFile = File(pickedFile.path);
      });
    }
  }

  void _updateStudent() {
    setState(() {
      isLoading = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });
      Navigator.pop(context);
    });
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    studentNameController.dispose();
    classController.dispose();
    sectionController.dispose();
    rollNumberController.dispose();
    phoneNumberController.dispose();
    parentsNameController.dispose();
    parentsPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Edit Student',
        backgroundColor: Colors.transparent,
        showText: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RequiredLabel("Student Name"),
                  const SizedBox(height: 6),
                  nameTextField(
                    controller: studentNameController,
                    hintName: 'e.g. Sumit Sharma',
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextLabel("Class"),
                            const SizedBox(height: 6),
                            nameTextField(
                              controller: classController,
                              hintName: '8',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextLabel("Section"),
                            const SizedBox(height: 6),
                            nameTextField(
                              controller: sectionController,
                              hintName: 'A',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextLabel("Roll Number"),
                  const SizedBox(height: 6),
                  nameTextField(
                    controller: rollNumberController,
                    hintName: 'e.g. 55',
                  ),
                  const SizedBox(height: 16),

                  TextLabel("Phone Number"),
                  const SizedBox(height: 6),
                  phoneNumberTextField(
                    controller: phoneNumberController,
                    hintName: 'e.g. +91 9376475677',
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),

                  TextLabel("Parents name"),
                  const SizedBox(height: 6),
                  nameTextField(
                    controller: parentsNameController,
                    hintName: 'e.g. Shubham Sharma',
                  ),
                  const SizedBox(height: 16),

                  TextLabel("Parents Phone"),
                  const SizedBox(height: 6),
                  phoneNumberTextField(
                    controller: parentsPhoneController,
                    hintName: 'e.g. +91 9987874874',
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),

                  TextLabel("Upload Image"),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.whiteColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppTheme.backBtnBgColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.backBtnBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Choose file',
                              style: MyStyles.regularText(
                                size: 14,
                                color: AppTheme.black_Color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              studentImageFile != null
                                  ? studentImageFile!.path.split('/').last
                                  : (widget.student.profilePhotoUrl != null &&
                                  widget.student.profilePhotoUrl!.isNotEmpty
                                  ? widget.student.profilePhotoUrl!.split('/').last
                                  : 'No file choosen'),
                              style: MyStyles.regularText(
                                size: 14,
                                color: AppTheme.graySubTitleColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    title: "Cancel",
                    isLoading: false,
                    color: AppTheme.backBtnBgColor,
                    onTap: _cancel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    title: "Update Student",
                    isLoading: isLoading,
                    color: AppTheme.btnColor,
                    onTap: _updateStudent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
