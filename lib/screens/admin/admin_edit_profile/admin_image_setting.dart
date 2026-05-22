import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/providers/image_settings/image_settings_cubit.dart';
import 'package:idmitra/providers/school/school_cubit.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:idmitra/utils/common_widgets/drop_down/drop_down.dart';
import 'package:idmitra/components/my_font_weight.dart';

class AdminImageSettingsScreen extends StatefulWidget {
  final String schoolId;
  final int? schoolIntId;
  const AdminImageSettingsScreen({super.key, required this.schoolId, this.schoolIntId});

  @override
  State<AdminImageSettingsScreen> createState() =>
      _AdminImageSettingsScreenState();
}

class _AdminImageSettingsScreenState extends State<AdminImageSettingsScreen> {
  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController watermarkTextController = TextEditingController();
  final TextEditingController watermarkColorController = TextEditingController();
  final TextEditingController gradientStartController = TextEditingController();
  final TextEditingController gradientEndController = TextEditingController();
  final TextEditingController bgColorController = TextEditingController();

  Color selectedBgColor = Colors.grey;

  String? selectedShape;
  String? selectedWatermarkPosition;
  String? selectedGradientDirection;

  bool removeBg = false;
  bool gradientEnabled = false;

  int? widthPx;
  int? heightPx;

  // Dynamic lists populated from API response
  List<Map<String, String>> dynamicShapeList = [];
  List<Map<String, String>> dynamicWatermarkPositionList = [];
  List<Map<String, String>> dynamicGradientDirectionList = [];

  String _slugToTitle(String slug) {
    return slug
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }

  void _populateFromData(Map<String, dynamic> data) {
    widthController.text = (data['width_mm'] ?? '').toString();
    heightController.text = (data['height_mm'] ?? '').toString();
    widthPx = data['width_px'] as int?;
    heightPx = data['height_px'] as int?;

    final bgColor = data['background_color']?.toString() ?? '';
    bgColorController.text = bgColor;
    selectedBgColor = _hexToColor(bgColor);

    final shapeSlug = data['image_shape']?.toString();
    if (shapeSlug != null && shapeSlug.isNotEmpty) {
      dynamicShapeList = [{"slug": shapeSlug, "title": _slugToTitle(shapeSlug)}];
      selectedShape = shapeSlug;
    } else {
      dynamicShapeList = [];
      selectedShape = null;
    }

    final positionSlug = data['watermark_position']?.toString();
    if (positionSlug != null && positionSlug.isNotEmpty) {
      dynamicWatermarkPositionList = [{"slug": positionSlug, "title": _slugToTitle(positionSlug)}];
      selectedWatermarkPosition = positionSlug;
    } else {
      dynamicWatermarkPositionList = [];
      selectedWatermarkPosition = null;
    }

    final gradientSlug = data['gradient_direction']?.toString();
    if (gradientSlug != null && gradientSlug.isNotEmpty) {
      dynamicGradientDirectionList = [{"slug": gradientSlug, "title": _slugToTitle(gradientSlug)}];
      selectedGradientDirection = gradientSlug;
    } else {
      dynamicGradientDirectionList = [];
      selectedGradientDirection = null;
    }

    watermarkTextController.text =
        (data['water_mark_text'] != null && data['water_mark_text'].toString() != 'null')
            ? data['water_mark_text'].toString()
            : '';
    watermarkColorController.text =
        (data['water_mark_text_color'] != null && data['water_mark_text_color'].toString() != 'null')
            ? data['water_mark_text_color'].toString()
            : '';
    gradientStartController.text =
        (data['gradient_start_color'] != null && data['gradient_start_color'].toString() != 'null')
            ? data['gradient_start_color'].toString()
            : '';
    gradientEndController.text =
        (data['gradient_end_color'] != null && data['gradient_end_color'].toString() != 'null')
            ? data['gradient_end_color'].toString()
            : '';

    removeBg = data['remove_bg'] == true;
    gradientEnabled = data['gradient_enabled'] == true;
  }

  Color _hexToColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
    } catch (_) {}
    return Colors.grey;
  }

  void _openColorPicker(Color current, Function(Color) onPicked) {
    Color tempColor = current;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Pick a color",
            style: MyStyles.boldText(size: 16, color: Colors.black)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (color) => tempColor = color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel",
                style: MyStyles.regularText(size: 14, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              onPicked(tempColor);
              Navigator.pop(context);
            },
            child: Text("Select",
                style: MyStyles.mediumText(size: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _colorToHex(Color color) =>
      "#${color.value.toRadixString(16).substring(2)}";

  Future<void> _onSave(BuildContext context) async {
    final schoolId = widget.schoolId;

    if (schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("School ID not found")),
      );
      return;
    }

    final body = {
      "width_mm": int.tryParse(widthController.text),
      "height_mm": int.tryParse(heightController.text),
      "image_shape": selectedShape,
      "background_color": bgColorController.text,
      "water_mark_text": watermarkTextController.text,
      "water_mark_text_color": watermarkColorController.text,
      "watermark_position": selectedWatermarkPosition,
      "remove_bg": removeBg,
      "gradient_enabled": gradientEnabled,
      "gradient_start_color": gradientStartController.text,
      "gradient_end_color": gradientEndController.text,
      "gradient_direction": selectedGradientDirection,
    };

    context.read<ImageSettingsCubit>().saveImageSettings(
          schoolId: schoolId,
          body: body,
        );
  }

  @override
  Widget build(BuildContext context) {
    final outerContext = context;
    return BlocProvider(
      create: (_) => ImageSettingsCubit()
        ..fetchImageSettings(schoolId: widget.schoolId),
      child: BlocConsumer<ImageSettingsCubit, ImageSettingsState>(
        listener: (context, state) {
          if (state is ImageSettingsFetchLoaded) {
            setState(() => _populateFromData(state.data));
          } else if (state is ImageSettingsSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            if (state.imageShape != null && widget.schoolIntId != null) {
              try {
                outerContext.read<SchoolCubit>().updateSchoolImageShape(
                      widget.schoolIntId!,
                      state.imageShape!,
                    );
              } catch (_) {}
            }
          } else if (state is ImageSettingsFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          } else if (state is ImageSettingsFetchFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final isFetchLoading = state is ImageSettingsFetchLoading;
          final isSaveLoading = state is ImageSettingsLoading;

          if (isFetchLoading) {
            return Scaffold(
              appBar: CommonAppBar(title: "Image Settings"),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: CommonAppBar(title: "Image Settings"),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField("Photo Width (mm)", widthController,
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildTextField("Photo Height (mm)", heightController,
                              keyboardType: TextInputType.phone)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widthPx != null && heightPx != null)
                    Text(
                      "Output size (approx @300 DPI): $widthPx x $heightPx px",
                      style: MyStyles.mediumText(size: 14, color: Colors.grey),
                    ),
                  const SizedBox(height: 20),
                  _buildDropdown("Shape", dynamicShapeList, selectedShape,
                      (val) => setState(() => selectedShape = val)),
                  const SizedBox(height: 20),
                  Text("Background Color",
                      style: MyStyles.boldText(size: 14, color: Colors.black)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                          child: nameTextField(
                              controller: bgColorController,
                              hintName: "Background Color")),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _openColorPicker(selectedBgColor, (color) {
                          setState(() {
                            selectedBgColor = color;
                            bgColorController.text = _colorToHex(color);
                          });
                        }),
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: selectedBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Remove Background (AI)",
                          style: MyStyles.boldText(size: 14, color: Colors.black)),
                      Switch(
                        value: removeBg,
                        onChanged: (val) => setState(() => removeBg = val),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Text("Watermark (optional)",
                      style: MyStyles.boldText(size: 14, color: Colors.black)),
                  const SizedBox(height: 10),
                  _buildTextField("Watermark Text", watermarkTextController),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField("Text Color", watermarkColorController)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                            "Position",
                            dynamicWatermarkPositionList,
                            selectedWatermarkPosition,
                            (val) => setState(() => selectedWatermarkPosition = val)),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Gradient (optional)",
                          style: MyStyles.boldText(size: 14, color: Colors.black)),
                      Switch(
                        value: gradientEnabled,
                        onChanged: (val) => setState(() => gradientEnabled = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextField("Start Color", gradientStartController),
                  const SizedBox(height: 10),
                  _buildTextField("End Color", gradientEndController),
                  const SizedBox(height: 10),
                  _buildDropdown("Direction", dynamicGradientDirectionList,
                      selectedGradientDirection,
                      (val) => setState(() => selectedGradientDirection = val)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      title: "Save Image Settings",
                      isLoading: isSaveLoading,
                      color: AppTheme.btnColor,
                      onTap: isSaveLoading ? () {} : () => _onSave(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MyStyles.boldText(size: 14, color: Colors.black)),
        const SizedBox(height: 5),
        nameTextField(
            controller: controller, hintName: "", keyboardType: keyboardType),
      ],
    );
  }

  Widget _buildDropdown(String label, List<Map<String, String>> items,
      String? selectedValue, Function(String) onChanged) {
    final matched = selectedValue == null || selectedValue.isEmpty
        ? null
        : items.cast<Map<String, String>?>().firstWhere(
            (e) => e?["slug"]?.toLowerCase() == selectedValue.toLowerCase(),
            orElse: () => null,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MyStyles.boldText(size: 14, color: Colors.black)),
        const SizedBox(height: 5),
        Dropdown<Map<String, String>>(
          key: ValueKey('${label}_$selectedValue'),
          value: matched,
          items: items,
          onChange: (value) {
            if (value == null) return;
            onChanged(value["slug"]!);
          },
          hintText: "Select",
          displayText: (int index, Map<String, String> value) =>
              value["title"] ?? "",
        ),
      ],
    );
  }
}
