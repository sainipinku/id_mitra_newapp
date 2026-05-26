import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:idmitra/models/staff/StaffDetailModel.dart';
import 'package:idmitra/models/staff/StaffListModel.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/providers/school/school_cubit.dart';

import 'package:idmitra/models/correction/CorrectionListModel.dart';
import 'package:idmitra/providers/correction/correction_cubit.dart';
import 'package:idmitra/providers/correction/correction_state.dart';
import 'package:idmitra/providers/staff_correction/staff_correction_cubit.dart';
import 'package:idmitra/providers/staff_correction/staff_correction_state.dart';
import 'package:idmitra/providers/staff_list/staff_list_cubit.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:idmitra/screens/staff/staff_order_page/staff_order_detail_page.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

import '../../orders/order_staff_page.dart';
import 'add_staff_form.dart';
import 'assign_classes_sheet.dart';
import 'staff_profile_page.dart';

String _resolveImageShape(BuildContext context, String schoolId) {
  String shape = 'rectangle';
  try {
    final schoolState = context.read<SchoolCubit>().state;
    final schoolIntId = int.tryParse(schoolId);
    if (schoolIntId != null) {
      if (schoolState.imageShapeMap.containsKey(schoolIntId)) {
        shape = schoolState.imageShapeMap[schoolIntId] ?? shape;
      } else {
        final match = schoolState.students.firstWhere(
              (s) => s.id == schoolIntId,
          orElse: () => SchoolDetailsModel(),
        );
        if (match.imageShape != null && match.imageShape!.isNotEmpty) {
          shape = match.imageShape!;
        }
      }
    }
  } catch (_) {}
  return shape;
}

Widget _clipByShape(Widget child, String shape,
    {double width = 60, double height = 60}) {
  final sized = SizedBox(width: width, height: height, child: child);
  switch (shape) {
    case 'round':
    case 'oval':
      return ClipOval(child: sized);
    case 'square':
      return ClipRRect(borderRadius: BorderRadius.zero, child: sized);
    case 'rectangle':
    default:
      return ClipRRect(borderRadius: BorderRadius.circular(6), child: sized);
  }
}

Widget _buildShapedPreview(String imageUrl, String shape) {
  final isLocal = !imageUrl.startsWith('http');
  final imageWidget = isLocal
      ? Image.file(
          File(imageUrl),
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            height: 300,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 80, color: Colors.grey),
          ),
        )
      : CachedNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 300,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 80, color: Colors.grey),
          ),
        );
  switch (shape) {
    case 'round':
    case 'oval':
      return ClipOval(child: imageWidget);
    case 'square':
      return ClipRRect(borderRadius: BorderRadius.zero, child: imageWidget);
    case 'rectangle':
    default:
      return ClipRRect(
          borderRadius: BorderRadius.circular(12), child: imageWidget);
  }
}


class StaffListingPage extends StatefulWidget {
  final String schoolId;
  final bool showAppBar;
  final bool isSchool;
  final SchoolDetailsModel? schoolDetailsModel;

  const StaffListingPage({
    super.key,
    required this.schoolId,
    this.showAppBar = true,
    this.isSchool = false,
    this.schoolDetailsModel,
  });

  @override
  State<StaffListingPage> createState() => _StaffListingPageState();
}

class _StaffListingPageState extends State<StaffListingPage>
    with SingleTickerProviderStateMixin {
  late final StaffListCubit _cubit;
  late final StaffCorrectionCubit _correctionCubit;
  late final SchoolCubit _schoolCubit;
  late final TabController _tabController;
  String? _schoolId;

  @override
  void initState() {
    super.initState();
    _cubit = StaffListCubit();
    _correctionCubit = StaffCorrectionCubit();
    _schoolCubit = SchoolCubit();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSchoolAndFetch();
  }

  void _onTabChanged() {
    if (_schoolId == null || _tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      _correctionCubit.fetchStaffCorrection(schoolId: _schoolId!);
    } else if (_tabController.index == 2) {
      _cubit.fetchStaffOrders(schoolId: _schoolId!, reset: true);
    }
  }

  Future<void> _loadSchoolAndFetch() async {
    String id = widget.schoolId;
    if (id.isEmpty) {
      final school = await UserLocal.getSchool();
      id = school['schoolId'] ?? '';
    }
    if (mounted) {
      setState(() => _schoolId = id);
      if (id.isNotEmpty) {
        _cubit.fetchStaff(schoolId: id);
        final schoolIntId = int.tryParse(id);
        if (schoolIntId != null) {
          _schoolCubit.fetchAndApplyImageShape(schoolIntId);
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _cubit.close();
    _correctionCubit.close();
    _schoolCubit.close();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_schoolId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabBar = TabBar(
      controller: _tabController,
      labelColor: AppTheme.btnColor,
      unselectedLabelColor: AppTheme.graySubTitleColor,
      indicatorColor: AppTheme.btnColor,
      indicatorWeight: 2.5,
      labelStyle: MyStyles.mediumText(size: 13, color: Colors.white),
      unselectedLabelStyle:
      MyStyles.regularText(size: 13, color: Colors.white),
      tabs: const [
        Tab(text: 'Staff List'),
        Tab(text: 'Correction List'),
        Tab(text: 'Staff Orders'),
      ],
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _correctionCubit),
        BlocProvider.value(value: _schoolCubit),
      ],
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.all(10.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  border: Border.all(color: AppTheme.titleHintColor),
                  borderRadius:
                  const BorderRadius.all(Radius.circular(8)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(5.0),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.black87),
                ),
              ),
            ),
          ),
          centerTitle: true,
          title: Text('Staff Listings',
              style: MyStyles.boldText(size: 20, color: Colors.black)),
          bottom: tabBar,
        )
            : PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: Material(color: Colors.white, child: tabBar),
        ),
        body: Column(
          children: [
            _StaffTabCountBanner(tabController: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  BlocProvider.value(
                    value: _cubit,
                    child: _StaffListBody(
                      schoolId: _schoolId!,
                      cubit: _cubit,
                      showAppBar: false,
                    ),
                  ),
                  BlocProvider.value(
                    value: _correctionCubit,
                    child: _StaffCorrectionTab(
                        schoolId: _schoolId!, isSchool: widget.isSchool),
                  ),
                  BlocProvider.value(
                    value: _cubit,
                    child: _StaffOrdersTab(
                        schoolId: _schoolId!, isSchool: widget.isSchool),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffListBody extends StatefulWidget {
  final String schoolId;
  final StaffListCubit cubit;
  final bool showAppBar;

  const _StaffListBody(
      {required this.schoolId, required this.cubit, this.showAppBar = true});

  @override
  State<_StaffListBody> createState() => _StaffListBodyState();
}

class _StaffListBodyState extends State<_StaffListBody> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  final Set<int> _selectedIds = {};
  final Map<int, String> _idToUuid = {};

  void _toggleSelect(StaffListModel staff) {
    setState(() {
      if (_selectedIds.contains(staff.id)) {
        _selectedIds.remove(staff.id);
      } else {
        _selectedIds.add(staff.id);
        _idToUuid[staff.id] = staff.uuid;
      }
    });
  }

  void _selectAll(List<StaffListModel> list) {
    setState(() {
      for (final s in list) {
        _selectedIds.add(s.id);
        _idToUuid[s.id] = s.uuid;
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  void _showProcessChecklistDialog(BuildContext ctx) {
    final uuids = _selectedIds
        .where((id) => _idToUuid.containsKey(id))
        .map((id) => _idToUuid[id]!)
        .toList();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => StaffCorrectionCubit(),
        child: _StaffProcessChecklistDialog(
          schoolId: widget.schoolId,
          staffUuids: uuids,
          onSuccess: () {
            _clearSelection();
            widget.cubit.fetchStaff(
              schoolId: widget.schoolId,
              search: _searchCtrl.text.trim(),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      widget.cubit.fetchStaff(
        schoolId: widget.schoolId,
        search: _searchCtrl.text.trim(),
        isLoadMore: true,
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await widget.cubit.fetchStaff(
      schoolId: widget.schoolId,
      search: _searchCtrl.text.trim(),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.cubit.fetchStaff(schoolId: widget.schoolId, search: value.trim());
    });
  }

  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddStaffFormPage(editStaff: null, schoolId: widget.schoolId),
      ),
    );
    if (result != null && mounted) {
      if (result is StaffListModel) {
        widget.cubit.prependStaff(result);
      } else {
        widget.cubit.fetchStaff(
          schoolId: widget.schoolId,
          search: _searchCtrl.text.trim(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: widget.showAppBar
          ? CommonAppBar(
        title: 'Staff Listings',
        backgroundColor: Colors.white,
        showText: true,
      )
          : null,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.btnColor,
        onPressed: _navigateToAdd,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                style: MyStyles.regularText(
                    size: 14, color: AppTheme.black_Color),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.whiteColor,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Search staff...',
                  prefixIcon: const Icon(Icons.search),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                    BorderSide(color: AppTheme.backBtnBgColor),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                    BorderSide(color: AppTheme.backBtnBgColor),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  hintStyle: MyStyles.regularText(
                      size: 14, color: AppTheme.graySubTitleColor),
                ),
              ),
            ),
            if (_selectedIds.isNotEmpty)
              BlocBuilder<StaffListCubit, StaffListState>(
                builder: (_, staffState) => _StaffListSelectionToolbar(
                  selectedCount: _selectedIds.length,
                  onSelectAll: () => _selectAll(staffState.list),
                  onClear: _clearSelection,
                  actionLabel: 'Process Checklist',
                  onAction: () => _showProcessChecklistDialog(context),
                ),
              ),
            Expanded(
              child: BlocBuilder<StaffListCubit, StaffListState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const ShimmerList(
                        expanded: false, itemCount: 6);
                  }
                  if (state.error != null && state.list.isEmpty) {
                    final isPermissionError = state.error!
                        .toLowerCase()
                        .contains('permission') ||
                        state.error!.toLowerCase().contains('denied') ||
                        state.error!
                            .toLowerCase()
                            .contains('unauthorized') ||
                        state.error!
                            .toLowerCase()
                            .contains('forbidden');
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height:
                          MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPermissionError
                                        ? Icons.lock_outline
                                        : Icons.error_outline,
                                    size: 56,
                                    color: isPermissionError
                                        ? Colors.orange.shade400
                                        : Colors.red.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(state.error!,
                                      style: MyStyles.regularText(
                                          size: 14,
                                          color: AppTheme.black_Color),
                                      textAlign: TextAlign.center),
                                  if (!isPermissionError) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _refresh,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  if (state.list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height:
                          MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Image.asset(
                                'assets/images/no_data.png',
                                height: 200),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount:
                    state.list.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i < state.list.length) {
                        final staff = state.list[i];
                        final isSelected = _selectedIds.contains(staff.id);
                        return _StaffCard(
                          staff: staff,
                          schoolId: widget.schoolId,
                          cubit: widget.cubit,
                          isSelected: isSelected,
                          onToggle: () => _toggleSelect(staff),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _StaffCard extends StatefulWidget {
  final StaffListModel staff;
  final String schoolId;
  final StaffListCubit cubit;
  final bool isSelected;
  final VoidCallback? onToggle;

  const _StaffCard({
    required this.staff,
    required this.schoolId,
    required this.cubit,
    this.isSelected = false,
    this.onToggle,
  });

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  String? _uploadedPhotoUrl;
  File? _photoFile;

  @override
  void didUpdateWidget(covariant _StaffCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.staff.profilePhotoUrl != null &&
        widget.staff.profilePhotoUrl!.isNotEmpty &&
        _uploadedPhotoUrl == widget.staff.profilePhotoUrl) {
      _uploadedPhotoUrl = null;
    }
  }

  StaffListModel get staff => widget.staff;
  String get schoolId => widget.schoolId;
  StaffListCubit get cubit => widget.cubit;

  String? get _activePhotoUrl {
    if (_uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty) {
      return _uploadedPhotoUrl;
    }
    final url = staff.profilePhotoUrl;
    return (url != null && url.isNotEmpty) ? url : null;
  }


  Future<void> _fromCamera() async {
    final picked =
    await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) await _uploadPhoto(picked.path);
  }

  Future<void> _fromGallery() async {
    final picked =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _photoFile = File(picked.path);
      await _cropAndUpload();
    }
  }

  Future<void> _cropAndUpload() async {
    if (_photoFile == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _photoFile!.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppTheme.MainColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped != null) await _uploadPhoto(cropped.path);
  }

  Future<void> _uploadPhoto(String path) async {
    final newUrl = await cubit.uploadStaffPhoto(
      schoolId: schoolId,
      uuid: staff.uuid,
      imagePath: path,
    );
    if (newUrl != null && mounted) {
      setState(() => _uploadedPhotoUrl = newUrl);
    }
  }


  Future<void> _uploadSignature(String path) async {
    await cubit.uploadStaffSignature(
      schoolId: schoolId,
      uuid: staff.uuid,
      imagePath: path,
    );
    if (mounted) {
      final state = cubit.state;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.signatureUploadError ??
            state.signatureUploadSuccess ??
            'Signature uploaded'),
        backgroundColor: state.signatureUploadError != null
            ? Colors.red
            : Colors.green,
      ));
      cubit.clearSignatureMessages();
    }
  }


  Widget _buildPhoto(BuildContext context, String initials) {
    const shape = 'rectangle';

    return BlocBuilder<StaffListCubit, StaffListState>(
      buildWhen: (p, c) =>
      p.isPhotoUploading(staff.uuid) != c.isPhotoUploading(staff.uuid),
      builder: (_, cubitState) {
        final isUploading = cubitState.isPhotoUploading(staff.uuid);
        Widget content;
        if (isUploading) {
          content = const SizedBox(
            height: 60,
            width: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        } else if (staff.isPhotoPendingSync && staff.offlinePhotoPath != null) {
          final file = File(staff.offlinePhotoPath!);
          content = FutureBuilder<bool>(
            future: file.exists(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return Image.file(
                  file,
                  height: 60,
                  width: 60,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                );
              }
              return _placeholder(initials);
            },
          );
        } else if (_activePhotoUrl != null) {
          final isLocal = !_activePhotoUrl!.startsWith('http');
          content = isLocal
              ? Image.file(
                  File(_activePhotoUrl!),
                  height: 60,
                  width: 60,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => _placeholder(initials),
                )
              : CachedNetworkImage(
                  imageUrl: _activePhotoUrl!,
                  height: 60,
                  width: 60,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => _placeholder(initials),
                  errorWidget: (_, __, ___) => _placeholder(initials),
                );
        } else {
          content = _placeholder(initials);
        }
        return _clipByShape(content, shape);
      },
    );
  }

  Widget _placeholder(String initials) => Container(
    height: 60,
    width: 60,
    decoration: BoxDecoration(
      color: AppTheme.btnColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Center(
      child: Text(initials,
          style: MyStyles.boldText(size: 18, color: AppTheme.btnColor)),
    ),
  );


  void _showImagePreview(BuildContext context, String imageUrl) {
    final shape = _resolveImageShape(context, schoolId);
    final isOffline = staff.isPhotoPendingSync && staff.offlinePhotoPath != null;
    final displayPath = isOffline ? staff.offlinePhotoPath! : (_activePhotoUrl ?? imageUrl);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4,
                    child: _buildShapedPreview(displayPath, shape),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fromCamera();
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text("Camera"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fromGallery();
                        },
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text("Gallery"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Future.delayed(
                              const Duration(milliseconds: 300),
                              _fromCamera);
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text("Retake"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Image',
                style: MyStyles.boldText(size: 14, color: Colors.black)),
            const SizedBox(height: 15),
            _pickerItem(
              icon: 'assets/icons/camera_single.svg',
              title: 'Camera',
              onTap: () {
                Navigator.pop(sheetCtx);
                Future.delayed(
                    const Duration(milliseconds: 300), _fromCamera);
              },
            ),
            _divider(),
            _pickerItem(
              icon: 'assets/icons/choose_from_gallery.svg',
              title: 'Gallery',
              onTap: () {
                Navigator.pop(sheetCtx);
                Future.delayed(
                    const Duration(milliseconds: 300), _fromGallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSignaturePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Upload Signature',
                style: MyStyles.boldText(size: 14, color: Colors.black)),
            const SizedBox(height: 15),
            _pickerItem(
              icon: 'assets/icons/camera_single.svg',
              title: 'Camera',
              onTap: () {
                Navigator.pop(sheetCtx);
                Future.delayed(const Duration(milliseconds: 300), () async {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.camera);
                  if (picked != null && context.mounted) {
                    await _uploadSignature(picked.path);
                  }
                });
              },
            ),
            _divider(),
            _pickerItem(
              icon: 'assets/icons/choose_from_gallery.svg',
              title: 'Gallery',
              onTap: () {
                Navigator.pop(sheetCtx);
                Future.delayed(const Duration(milliseconds: 300), () async {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked != null && context.mounted) {
                    await _uploadSignature(picked.path);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerItem(
      {required String icon,
        required String title,
        required VoidCallback onTap,
        Color color = Colors.black}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(icon),
          const SizedBox(width: 10),
          Text(title, style: MyStyles.regularText(size: 14, color: color)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    height: 1,
    color: Colors.grey.shade300,
  );


  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                        color: Colors.red.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 50, color: Colors.red.shade400),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Are you sure you want to\ndelete this staff?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      title: "Yes, I'm sure",
                      color: Colors.red,
                      onTap: () async {
                        Navigator.pop(context);
                        final success = await cubit.deleteStaff(
                            schoolId: schoolId, uuid: staff.uuid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(success
                                ? 'Staff deleted successfully'
                                : 'Failed to delete staff'),
                            backgroundColor:
                            success ? Colors.green : Colors.red,
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      title: 'No, cancel',
                      color: Colors.grey.shade300,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 50, color: Colors.blue.shade400),
                ),
                const SizedBox(height: 16),
                Text('Change Password',
                    style: MyStyles.boldText(
                        size: 16, color: AppTheme.black_Color)),
                const SizedBox(height: 4),
                Text(staff.name,
                    textAlign: TextAlign.center,
                    style: MyStyles.regularText(
                        size: 13, color: AppTheme.graySubTitleColor)),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('New Password',
                      style: MyStyles.mediumText(
                          size: 13, color: AppTheme.black_Color)),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: passwordController,
                  hintText: '••••••••',
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.graySubTitleColor,
                    ),
                    onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Confirm Password',
                      style: MyStyles.mediumText(
                          size: 13, color: AppTheme.black_Color)),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: confirmPasswordController,
                  hintText: '••••••••',
                  obscureText: obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.graySubTitleColor,
                    ),
                    onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        title: 'Change',
                        color: AppTheme.btnColor,
                        onTap: () async {
                          final password =
                          passwordController.text.trim();
                          final confirm =
                          confirmPasswordController.text.trim();
                          if (password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a password'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          if (password != confirm) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext);
                          final success = await cubit.changeStaffPassword(
                            schoolId: schoolId,
                            uuid: staff.uuid,
                            password: password,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Password changed successfully'
                                    : 'Failed to change password'),
                                backgroundColor:
                                success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        title: 'Cancel',
                        color: AppTheme.backBtnBgColor,
                        onTap: () => Navigator.pop(dialogContext),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final initials = staff.name.trim().isNotEmpty
        ? staff.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase()
        : '?';

    final hasPhoto = _activePhotoUrl != null;

    return GestureDetector(
      onTap: () async {
        final editStaff = StaffDetailModel(
          id: staff.id,
          uuid: staff.uuid,
          name: staff.name,
          designation: staff.designation,
          department: staff.department,
          email: staff.email,
          phone: staff.phone,
          whatsappPhone: staff.whatsappPhone,
          address: staff.address,
          profilePhotoUrl: staff.profilePhotoUrl ?? '',
          roleName: staff.roleName,
          roleId: staff.roleId,
          status: staff.status,
          emergencyContacts: [],
          dob: staff.dob,
          fatherName: staff.fatherName,
          motherName: staff.motherName,
          husbandName: staff.husbandName,
          gender: staff.gender,
          bloodGroup: staff.bloodGroup,
          pincode: staff.pincode,
          employeeId: staff.employeeId,
          nationalCode: staff.nationalCode,
          loginId: staff.loginId,
          dateOfJoining: staff.dateOfJoining,
        );
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AddStaffFormPage(editStaff: editStaff, schoolId: schoolId),
          ),
        );
        if ((result == true || result is StaffDetailModel || result is StaffListModel) && mounted) {
          cubit.fetchStaff(schoolId: schoolId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggle?.call(),
                    activeColor: AppTheme.btnColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(color: AppTheme.graySubTitleColor),
                  ),
                ),
              ),
            ),
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    final url = _activePhotoUrl;
                    if (url != null) {
                      _showImagePreview(context, url);
                    } else {
                      _fromCamera();
                    }
                  },
                  child: _buildPhoto(context, initials),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () {
                      final url = _activePhotoUrl;
                      if (url != null) {
                        _showImagePreview(context, url);
                      } else {
                        Future.delayed(Duration.zero, _fromCamera);
                      }
                    },
                    child: Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        hasPhoto ? Icons.preview : Icons.camera_alt,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(staff.name,
                            style: MyStyles.boldText(
                                size: 16, color: AppTheme.black_Color),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (staff.department.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('• ${staff.department}',
                              style: MyStyles.boldText(
                                  size: 14, color: AppTheme.btnColor),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if ([staff.designation, staff.roleName]
                      .any((s) => s.isNotEmpty))
                    Text(
                      [staff.designation, staff.roleName]
                          .where((s) => s.isNotEmpty)
                          .join(' • '),
                      style: MyStyles.regularText(
                          size: 12, color: AppTheme.graySubTitleColor),
                    ),
                  const SizedBox(height: 3),
                  if (staff.phone.isNotEmpty)
                    Text('Phone: ${staff.phone}',
                        style: MyStyles.regularText(
                            size: 12, color: AppTheme.graySubTitleColor)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                if (value == 'delete') {
                  _confirmDelete(context);
                } else if (value == 'change_password') {
                  _showChangePasswordDialog(context);
                } else if (value == 'assign_classes') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => BlocProvider(
                      create: (_) => OrdersCubit()
                        ..fetchSchoolClasses(schoolId),
                      child: AssignClassesSheet(
                        schoolId: schoolId,
                        staffUuid: staff.uuid,
                        staffName: staff.name,
                        cubit: cubit,
                      ),
                    ),
                  );
                } else if (value == 'upload_signature') {
                  _showSignaturePicker(context);
                } else if (value == 'toggle') {
                  final success = await cubit.toggleStaffStatus(
                    schoolId: schoolId,
                    uuid: staff.uuid,
                    currentStatus: staff.status,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? 'Status updated'
                          : 'Failed to update status'),
                      backgroundColor: success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 1),
                    ));
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        staff.status == 1
                            ? Icons.toggle_on
                            : Icons.toggle_off,
                        size: 22,
                        color: staff.status == 1 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(staff.status == 1 ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'assign_classes',
                  child: Row(children: [
                    Icon(Icons.class_outlined, size: 16, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Assign Classes'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'upload_signature',
                  child: Row(children: [
                    Icon(Icons.draw_outlined, size: 16, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Upload Signature'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'change_password',
                  child: Row(children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Change Password'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _StaffCorrectionTab extends StatefulWidget {
  final String schoolId;
  final bool isSchool;
  const _StaffCorrectionTab(
      {required this.schoolId, this.isSchool = false});

  @override
  State<_StaffCorrectionTab> createState() => _StaffCorrectionTabState();
}

class _StaffCorrectionTabState extends State<_StaffCorrectionTab> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<StaffCorrectionCubit>().fetchStaffCorrection(
          schoolId: widget.schoolId,
          isLoadMore: true,
          search: _searchCtrl.text.trim(),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<StaffCorrectionCubit>().fetchStaffCorrection(
        schoolId: widget.schoolId,
        search: value.trim(),
      );
    });
  }

  void _showDownloadDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: ctx.read<StaffCorrectionCubit>(),
        child: _StaffDownloadChecklistDialog(schoolId: widget.schoolId),
      ),
    );
  }

  void _showCreateOrderDialog(BuildContext ctx) {
    final staffState = ctx.read<StaffCorrectionCubit>().state;
    // API expects correction item uuids in card_users, not staff uuids
    final selectedUuids = staffState.items
        .where((item) =>
    staffState.selectedIds.contains(item.id) &&
        item.uuid != null &&
        item.uuid!.trim().isNotEmpty)
        .map((item) => item.uuid!.trim())
        .toList();

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: ctx.read<StaffCorrectionCubit>(),
        child: _CreateOrderDialog(
          schoolId: widget.schoolId,
          studentUuids: selectedUuids,
          onSuccess: () {
            // Refresh Staff Orders tab after order created (online or offline)
            ctx.read<StaffListCubit>().fetchStaffOrders(
              schoolId: widget.schoolId,
              reset: true,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.btnColor,
        tooltip: 'Download',
        onPressed: () => _showDownloadDialog(context),
        child: const Icon(Icons.download_rounded, color: Colors.white),
      ),
      body: BlocListener<StaffCorrectionCubit, StaffCorrectionState>(
        listenWhen: (p, c) =>
        p.sendOrderSuccess != c.sendOrderSuccess ||
            p.sendOrderError != c.sendOrderError,
        listener: (context, state) {
          if (state.sendOrderSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Order created successfully!'),
              backgroundColor: AppTheme.btnColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(12),
            ));
          }
          if (state.sendOrderError != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.sendOrderError!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(12),
            ));
          }
        },
        child: Column(
          children: [
            // ── Search field ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                style: MyStyles.regularText(
                    size: 14, color: AppTheme.black_Color),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.whiteColor,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Search staff...',
                  prefixIcon: const Icon(Icons.search),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                    BorderSide(color: AppTheme.backBtnBgColor),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                    BorderSide(color: AppTheme.backBtnBgColor),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  hintStyle: MyStyles.regularText(
                      size: 14, color: AppTheme.graySubTitleColor),
                ),
              ),
            ),
            BlocBuilder<StaffCorrectionCubit, StaffCorrectionState>(
              buildWhen: (p, c) =>
              p.selectedIds != c.selectedIds ||
                  p.sendOrderLoading != c.sendOrderLoading,
              builder: (ctx, s) {
                if (s.selectedIds.isEmpty) return const SizedBox.shrink();
                return _StaffListSelectionToolbar(
                  selectedCount: s.selectedIds.length,
                  onSelectAll: () => ctx.read<StaffCorrectionCubit>().selectAll(),
                  onClear: () => ctx.read<StaffCorrectionCubit>().clearSelection(),
                  actionLabel: 'Create Order',
                  actionIcon: Icons.send_rounded,
                  actionLoading: s.sendOrderLoading,
                  onAction: s.sendOrderLoading ? null : () => _showCreateOrderDialog(context),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<StaffCorrectionCubit, StaffCorrectionState>(
                builder: (context, state) {
                  if (state.loading && state.items.isEmpty) {
                    return const ShimmerList(expanded: false, itemCount: 6);
                  }
                  if (state.error != null && state.items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 12),
                            Text(state.error!,
                                style: MyStyles.regularText(
                                    size: 14, color: AppTheme.black_Color),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => context
                                  .read<StaffCorrectionCubit>()
                                  .fetchStaffCorrection(
                                  schoolId: widget.schoolId),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.btnColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.items.isEmpty) {
                    return RefreshIndicator(
                      color: AppTheme.btnColor,
                      onRefresh: () async => context
                          .read<StaffCorrectionCubit>()
                          .fetchStaffCorrection(
                        schoolId: widget.schoolId,
                        search: _searchCtrl.text.trim(),
                      ),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height:
                            MediaQuery.of(context).size.height * 0.55,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/images/no_data.png',
                                      height: 160),
                                  const SizedBox(height: 12),
                                  Text('No correction entries found',
                                      style: MyStyles.mediumText(
                                          size: 14,
                                          color:
                                          AppTheme.graySubTitleColor)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.btnColor,
                    onRefresh: () async => context
                        .read<StaffCorrectionCubit>()
                        .fetchStaffCorrection(
                      schoolId: widget.schoolId,
                      search: _searchCtrl.text.trim(),
                    ),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount:
                      state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i < state.items.length) {
                          final item = state.items[i];
                          final isSelected =
                          state.selectedIds.contains(item.id);
                          return _StaffCorrectionItemCard(
                            item: item,
                            schoolId: widget.schoolId,
                            isSelected: isSelected,
                            onToggle: () => context
                                .read<StaffCorrectionCubit>()
                                .toggleSelection(item.id),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.btnColor,
                                  strokeWidth: 2)),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _StaffDownloadChecklistDialog extends StatefulWidget {
  final String schoolId;
  const _StaffDownloadChecklistDialog({required this.schoolId});

  @override
  State<_StaffDownloadChecklistDialog> createState() =>
      __StaffDownloadChecklistDialogState();
}

class __StaffDownloadChecklistDialogState
    extends State<_StaffDownloadChecklistDialog> {
  Set<String> _selectedColumns = {};
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    context
        .read<StaffCorrectionCubit>()
        .fetchStaffDownloadColumns(schoolId: widget.schoolId);
  }

  void _toggleColumn(String key) {
    setState(() {
      if (_selectedColumns.contains(key)) {
        _selectedColumns.remove(key);
      } else {
        _selectedColumns.add(key);
      }
    });
  }

  Future<void> _printNow(BuildContext context) async {
    if (_selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one column'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Get all correction item uuids (all items, not just selected)
    final correctionState = context.read<StaffCorrectionCubit>().state;
    final ids = correctionState.items
        .where((item) => item.uuid != null && item.uuid!.isNotEmpty)
        .map((item) => item.uuid!)
        .toList();

    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No correction items found'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _downloading = true);

    final pdfBytes = await context
        .read<StaffCorrectionCubit>()
        .downloadStaffCorrectionList(
      schoolId: widget.schoolId,
      ids: ids,
      selected: _selectedColumns.toList(),
    );

    if (!mounted) return;
    setState(() => _downloading = false);

    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Staff_Correction_List_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to generate PDF'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StaffCorrectionCubit, StaffCorrectionState>(
      listenWhen: (p, c) =>
      p.columnsLoading != c.columnsLoading,
      listener: (ctx, state) {
        if (!state.columnsLoading &&
            state.downloadColumns.isNotEmpty &&
            _selectedColumns.isEmpty) {
          setState(() {
            _selectedColumns =
                state.downloadColumns.map((c) => c.key).toSet();
          });
        }
      },
      builder: (context, state) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Text('Download Checklist',
                      style: MyStyles.boldText(
                          size: 18, color: AppTheme.black_Color)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _downloading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53)
                        ]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select Data You Want to Display in Correction List',
                style: MyStyles.mediumText(
                    size: 13, color: AppTheme.graySubTitleColor),
              ),
              const SizedBox(height: 16),

              // ── Columns grid ──
              if (state.columnsLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                        color: AppTheme.btnColor, strokeWidth: 2),
                  ),
                )
              else if (state.downloadColumns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No columns available',
                      style: MyStyles.regularText(
                          size: 13,
                          color: AppTheme.graySubTitleColor)),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 4,
                  children: state.downloadColumns.map((col) {
                    final isSelected =
                    _selectedColumns.contains(col.key);
                    return GestureDetector(
                      onTap: () => _toggleColumn(col.key),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.btnColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.btnColor
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(col.label,
                                style: MyStyles.regularText(
                                    size: 12,
                                    color: AppTheme.black_Color),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 20),

              // ── Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _downloading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF4E50)]),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.replay_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Cancel',
                              style: MyStyles.mediumText(
                                  size: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _downloading
                        ? null
                        : () => _printNow(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _downloading
                            ? null
                            : const LinearGradient(
                            colors: [
                              Color(0xFF6C63FF),
                              Color(0xFF3B2FBF)
                            ]),
                        color: _downloading ? Colors.grey : null,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _downloading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.print_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Print Now',
                              style: MyStyles.mediumText(
                                  size: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _StaffCorrectionItemCard extends StatefulWidget {
  final StaffCorrectionItem item;
  final String schoolId;
  final bool isSelected;
  final VoidCallback? onToggle;

  const _StaffCorrectionItemCard({
    required this.item,
    required this.schoolId,
    this.isSelected = false,
    this.onToggle,
  });

  @override
  State<_StaffCorrectionItemCard> createState() =>
      _StaffCorrectionItemCardState();
}

class _StaffCorrectionItemCardState extends State<_StaffCorrectionItemCard> {
  String? _uploadedPhotoUrl;
  File? _photoFile;

  // Color _statusColor(String? status) {
  //   switch ((status ?? '').toLowerCase()) {
  //     case 'pending':
  //       return Colors.orange;
  //     case 'approved':
  //       return Colors.green;
  //     case 'rejected':
  //       return Colors.red;
  //     default:
  //       return Colors.grey;
  //   }
  // }

  String? get _currentPhotoUrl =>
      _uploadedPhotoUrl ?? widget.item.effectiveStaff?.profilePhotoUrl;

  Future<void> _fromCamera() async {
    final picked =
    await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) await _uploadPhoto(picked.path);
  }

  Future<void> _fromGallery() async {
    final picked =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _photoFile = File(picked.path);
      await _cropAndUpload();
    }
  }

  Future<void> _cropAndUpload() async {
    if (_photoFile == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _photoFile!.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppTheme.MainColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped != null) await _uploadPhoto(cropped.path);
  }

  Future<void> _uploadPhoto(String path) async {
    final staff = widget.item.effectiveStaff;
    if (staff == null) return;
    final newUrl =
    await context.read<StaffCorrectionCubit>().uploadStaffPhoto(
      schoolId: widget.schoolId,
      uuid: staff.uuid ?? '',
      imagePath: path,
    );
    if (newUrl != null && mounted) {
      setState(() => _uploadedPhotoUrl = newUrl);
    }
  }

  Widget _buildPhoto(BuildContext context, String initials) {
    const shape = 'rectangle';
    final staff = widget.item.effectiveStaff;
    final photoUrl = _currentPhotoUrl;
    final isOffline = staff?.isPhotoPendingSync == true && staff?.offlinePhotoPath != null;

    Widget content;
    if (isOffline) {
      final file = File(staff!.offlinePhotoPath!);
      content = FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Image.file(
              file,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            );
          }
          return _placeholder(initials);
        },
      );
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      final isLocal = !photoUrl.startsWith('http');
      content = isLocal
          ? Image.file(
              File(photoUrl),
              height: 60,
              width: 60,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => _placeholder(initials),
            )
          : CachedNetworkImage(
              imageUrl: photoUrl,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (_, __) => _placeholder(initials),
              errorWidget: (_, __, ___) => _placeholder(initials),
            );
    } else {
      content = _placeholder(initials);
    }
    return _clipByShape(content, shape);
  }

  Widget _placeholder(String initials) => Container(
    height: 60,
    width: 60,
    color: AppTheme.btnColor.withOpacity(0.12),
    child: Center(
      child: Text(initials,
          style:
          MyStyles.boldText(size: 18, color: AppTheme.btnColor)),
    ),
  );

  void _showImagePreview(BuildContext context, String imageUrl) {
    final shape = _resolveImageShape(context, widget.schoolId);
    final staff = widget.item.effectiveStaff;
    final isOffline = staff?.isPhotoPendingSync == true && staff?.offlinePhotoPath != null;
    final displayPath = isOffline ? staff!.offlinePhotoPath! : ((_currentPhotoUrl ?? '').isNotEmpty ? _currentPhotoUrl! : imageUrl);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4,
                    child: _buildShapedPreview(displayPath, shape),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fromCamera();
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text("Camera"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fromGallery();
                        },
                        icon:
                        const Icon(Icons.photo_library, size: 18),
                        label: const Text("Gallery"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _uploadedPhotoUrl = '');
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text("Remove"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.item.effectiveStaff;
    final photoUrl = _currentPhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final initials = (staff?.name ?? '').trim().isNotEmpty
        ? staff!.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ── CHANGE 2: Card hamesha white — select hone par sirf checkbox filled hoga ──
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggle?.call(),
                    activeColor: AppTheme.btnColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(color: AppTheme.graySubTitleColor),
                  ),
                ),
              ),
            ),
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (hasPhoto) {
                      _showImagePreview(context, photoUrl!);
                    } else {
                      Future.delayed(Duration.zero, _fromCamera);
                    }
                  },
                  child: _buildPhoto(context, initials),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () {
                      if (hasPhoto) {
                        _showImagePreview(context, photoUrl!);
                      } else {
                        Future.delayed(Duration.zero, _fromCamera);
                      }
                    },
                    child: Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        hasPhoto ? Icons.preview : Icons.camera_alt,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(staff?.name ?? 'Unknown',
                            style: MyStyles.boldText(
                                size: 15, color: AppTheme.black_Color),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if ((staff?.department ?? '').isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('• ${staff!.department}',
                              style: MyStyles.boldText(
                                  size: 13, color: AppTheme.btnColor),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if ([
                    staff?.designation ?? '',
                    staff?.roleName ?? ''
                  ].any((s) => s.isNotEmpty))
                    Text(
                      [staff?.designation ?? '', staff?.roleName ?? '']
                          .where((s) => s.isNotEmpty)
                          .join(' • '),
                      style: MyStyles.regularText(
                          size: 12, color: AppTheme.graySubTitleColor),
                    ),
                  if ((staff?.phone ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Phone: ${staff!.phone}',
                        style: MyStyles.regularText(
                            size: 12, color: AppTheme.graySubTitleColor)),
                  ],
                  if ((widget.item.remark ?? '').isNotEmpty &&
                      widget.item.remark != 'Offline Processed') ...[
                    const SizedBox(height: 4),
                    Text('Remark: ${widget.item.remark}',
                        style: MyStyles.regularText(
                            size: 11, color: AppTheme.graySubTitleColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            // if ((widget.item.status ?? '').isNotEmpty) ...[
            //   const SizedBox(width: 8),
            //   Container(
            //     padding:
            //     const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            //     decoration: BoxDecoration(
            //       color:
            //       //_statusColor(widget.item.status).withOpacity(0.12),
            //      // borderRadius: BorderRadius.circular(20),
            //     ),
            //     child: Text(
            //       widget.item.status!.toUpperCase(),
            //       style: MyStyles.mediumText(
            //           size: 10, color: _statusColor(widget.item.status)),
            //     ),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }
}


// ── Selection Toolbar ──
class _StaffListSelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool actionLoading;

  const _StaffListSelectionToolbar({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClear,
    required this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.btnColor.withOpacity(0.07),
        border: Border(left: BorderSide(color: AppTheme.btnColor, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.btnColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$selectedCount',
              style: MyStyles.boldText(size: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'selected',
            style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 14, color: Colors.grey.shade300),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSelectAll,
            child: Text(
              'Select All',
              style: MyStyles.mediumText(size: 12, color: AppTheme.btnColor),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Clear',
              style: MyStyles.mediumText(size: 12, color: AppTheme.graySubTitleColor),
            ),
          ),
          const Spacer(),
          if (actionLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.btnColor),
            )
          else if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.btnColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(actionIcon, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      actionLabel,
                      style: MyStyles.mediumText(size: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffOrdersTab extends StatefulWidget {
  final String schoolId;
  final bool isSchool;
  const _StaffOrdersTab(
      {required this.schoolId, this.isSchool = false});

  @override
  State<_StaffOrdersTab> createState() => _StaffOrdersTabState();
}

class _StaffOrdersTabState extends State<_StaffOrdersTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _dateFromCtrl = TextEditingController();
  final TextEditingController _dateToCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<StaffListCubit>().fetchStaffOrders(
          schoolId: widget.schoolId,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _resetAndFetch() {
    context.read<StaffListCubit>().fetchStaffOrders(
      schoolId: widget.schoolId,
      reset: true,
      search: _searchCtrl.text.trim(),
      status: context.read<StaffListCubit>().state.ordersSelectedStatus,
      dateFrom: _dateFromCtrl.text.trim(),
      dateTo: _dateToCtrl.text.trim(),
    );
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _dateFromCtrl.clear();
    _dateToCtrl.clear();
    context.read<StaffListCubit>().clearOrdersFilters(widget.schoolId);
  }

  Future<void> _showChangeStatusDialog(
      BuildContext ctx,
      List<int> ids,
      ) async {
    String? selectedStatus;
    String issueNote = '';
    bool confirming = false;

    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Change Order Status',
                        style: MyStyles.boldText(size: 18, color: AppTheme.black_Color),
                      ),
                    ),
                    GestureDetector(
                      onTap: confirming ? null : () => Navigator.pop(dialogCtx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Select new status',
                    style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedStatus != null ? AppTheme.btnColor : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      hint: Text('-- Select Status --',
                          style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.graySubTitleColor),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Select Status --',
                              style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor)),
                        ),
                        DropdownMenuItem<String>(
                          value: 'delivery_verified',
                          child: Text('Delivery Verified',
                              style: MyStyles.regularText(size: 13, color: AppTheme.black_Color)),
                        ),
                        DropdownMenuItem<String>(
                          value: 'printing_issue',
                          child: Text('Printing Issue',
                              style: MyStyles.regularText(size: 13, color: AppTheme.black_Color)),
                        ),
                      ],
                      onChanged: confirming
                          ? null
                          : (v) => setDialogState(() => selectedStatus = v),
                    ),
                  ),
                ),
                if (selectedStatus == 'printing_issue') ...[
                  const SizedBox(height: 12),
                  TextField(
                    style: MyStyles.regularText(size: 13, color: AppTheme.black_Color),
                    onChanged: (v) => issueNote = v,
                    decoration: InputDecoration(
                      hintText: 'Issue note (e.g. Card photo blur)',
                      hintStyle: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.btnColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: confirming ? null : () => Navigator.pop(dialogCtx),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.lightRedColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Text('Cancel',
                          style: MyStyles.mediumText(size: 13, color: AppTheme.cancelTextColor)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: (selectedStatus == null || confirming)
                          ? null
                          : () async {
                        setDialogState(() => confirming = true);
                        final success = await ctx
                            .read<StaffListCubit>()
                            .bulkUpdateStaffOrderStatus(
                          schoolId: widget.schoolId,
                          ids: ids,
                          status: selectedStatus!,
                          issueNote: issueNote,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (ctx.mounted) {
                          ctx.read<StaffListCubit>().clearStaffOrderSelection();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Status updated successfully'
                                  : 'Failed to update status'),
                              backgroundColor: success ? AppTheme.btnColor : Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(12),
                            ),
                          );
                          if (success) _resetAndFetch();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: confirming
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Text('Confirm',
                          style: MyStyles.mediumText(size: 13, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasActiveFilters {
    final s = context.read<StaffListCubit>().state;
    return s.ordersSelectedStatus.isNotEmpty ||
        _dateFromCtrl.text.isNotEmpty ||
        _dateToCtrl.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StaffListCubit, StaffListState>(
      buildWhen: (p, c) =>
      p.ordersLoading != c.ordersLoading ||
          p.ordersPaginationLoading != c.ordersPaginationLoading ||
          p.orders != c.orders ||
          p.ordersTotal != c.ordersTotal ||
          p.ordersError != c.ordersError ||
          p.ordersHasMore != c.ordersHasMore ||
          p.ordersSelectedStatus != c.ordersSelectedStatus ||
          p.selectedStaffOrderIds != c.selectedStaffOrderIds,
      builder: (context, state) {
        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: _searchBar(),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppTheme.LineColor),
                  const SizedBox(height: 10),
                  _statusDropdown(state),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child:
                          _dateField(_dateFromCtrl, 'From dd-mm-yyyy')),
                      const SizedBox(width: 8),
                      Expanded(
                          child:
                          _dateField(_dateToCtrl, 'To dd-mm-yyyy')),
                    ],
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _clearFilters,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppTheme.lightRedColor,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close,
                                  size: 12,
                                  color: AppTheme.cancelTextColor),
                              const SizedBox(width: 4),
                              Text('Clear Filters',
                                  style: MyStyles.mediumText(
                                      size: 11,
                                      color: AppTheme.cancelTextColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: state.ordersError != null && state.orders.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 12),
                    Text(state.ordersError!,
                        style: MyStyles.regularText(
                            size: 14, color: Colors.red),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _resetAndFetch,
                      icon:
                      const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.btnColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
                  : state.orders.isEmpty && !state.ordersLoading
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/no_data.png',
                        height: 160),
                    const SizedBox(height: 12),
                    Text('No staff orders found',
                        style: MyStyles.mediumText(
                            size: 14,
                            color: AppTheme.graySubTitleColor)),
                  ],
                ),
              )
                  : RefreshIndicator(
                color: AppTheme.btnColor,
                onRefresh: () async => _resetAndFetch(),
                child: Column(
                  children: [
                    if (state.selectedStaffOrderIds.isNotEmpty)
                      _StaffListSelectionToolbar(
                        selectedCount: state.selectedStaffOrderIds.length,
                        onSelectAll: () => context.read<StaffListCubit>().selectAllStaffOrders(),
                        onClear: () => context.read<StaffListCubit>().clearStaffOrderSelection(),
                        actionLabel: 'Change Status',
                        onAction: () => _showChangeStatusDialog(
                          context,
                          state.selectedStaffOrderIds.toList(),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: state.orders.length +
                            (state.ordersHasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i < state.orders.length) {
                            final order = state.orders[i];
                            final isSelected = state.selectedStaffOrderIds
                                .contains(order.id);
                            return _StaffOrderItemCard(
                              order: order,
                              schoolId: widget.schoolId,
                              isSelected: isSelected,
                              onToggle: () => context
                                  .read<StaffListCubit>()
                                  .toggleStaffOrderSelection(order.id),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.btnColor,
                                    strokeWidth: 2)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(
        size: 14, color: AppTheme.black_Color),
    onChanged: (_) {
      _debounce?.cancel();
      _debounce = Timer(
          const Duration(milliseconds: 500), _resetAndFetch);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.appBackgroundColor,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintText: 'Search staff orders...',
      prefixIcon: const Icon(Icons.search_rounded,
          size: 20, color: AppTheme.graySubTitleColor),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
            color: AppTheme.backBtnBgColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.btnColor),
        borderRadius: BorderRadius.circular(12),
      ),
      hintStyle: MyStyles.regularText(
          size: 13, color: AppTheme.graySubTitleColor),
    ),
  );

  Widget _statusDropdown(StaffListState state) {
    const _staffOrderFilterStatuses = [
      OrderStatusOption('', 'Filter By Status'),
      OrderStatusOption('re_order', 'Re-Order'),
      OrderStatusOption('printing_issue', 'Printing Issue'),
      OrderStatusOption('order_created', 'Order Created'),
      OrderStatusOption('work_in_process', 'Work In Process'),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.appBackgroundColor,
        border: Border.all(
            color: AppTheme.backBtnBgColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _staffOrderFilterStatuses.any((s) => s.value == state.ordersSelectedStatus)
              ? state.ordersSelectedStatus
              : '',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppTheme.graySubTitleColor),
          style: MyStyles.regularText(
              size: 13, color: AppTheme.black_Color),
          items: _staffOrderFilterStatuses
              .map((s) => DropdownMenuItem<String>(
              value: s.value,
              child: Text(s.label,
                  overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            context.read<StaffListCubit>().setOrdersFilter(
              schoolId: widget.schoolId,
              status: v ?? '',
              dateFrom: _dateFromCtrl.text.trim(),
              dateTo: _dateToCtrl.text.trim(),
              search: _searchCtrl.text.trim(),
            );
          },
        ),
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl, String hint) {
    return StatefulBuilder(
      builder: (context, setLocal) => AppTextField(
        controller: ctrl,
        hintText: hint,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.\-/]')),
          LengthLimitingTextInputFormatter(10),
          _StaffListDotDateFormatter(),
        ],
        suffixIcon: ctrl.text.isNotEmpty
            ? GestureDetector(
          onTap: () {
            ctrl.clear();
            setLocal(() {});
            _debounce?.cancel();
            _debounce = Timer(
                const Duration(milliseconds: 200), _resetAndFetch);
          },
          child: const Icon(Icons.close, size: 16),
        )
            : null,
        onChanged: (_) {
          setLocal(() {});
          if (ctrl.text.length == 10 || ctrl.text.isEmpty) {
            _debounce?.cancel();
            _debounce = Timer(
                const Duration(milliseconds: 400), _resetAndFetch);
          }
        },
      ),
    );
  }
}

class _StaffOrderItemCard extends StatelessWidget {
  final OrderStaffItem order;
  final String schoolId;
  final bool isSelected;
  final VoidCallback? onToggle;

  const _StaffOrderItemCard({
    required this.order,
    required this.schoolId,
    this.isSelected = false,
    this.onToggle,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF2DC24E);
      case 'cancelled':
        return AppTheme.cancelTextColor;
      case 'work_in_process':
        return AppTheme.btnColor;
      case 're_order':
        return AppTheme.PendingDotColor;
      default:
        return AppTheme.graySubTitleColor;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFE8F9ED);
      case 'cancelled':
        return AppTheme.lightRedColor;
      case 'work_in_process':
        return AppTheme.lightBlueColor;
      case 're_order':
        return AppTheme.PendingLightColor;
      default:
        return AppTheme.appBackgroundColor;
    }
  }

  String _statusLabel(String status) => kOrderStatuses
      .firstWhere(
        (s) => s.value == status,
    orElse: () =>
        OrderStatusOption(status, status.replaceAll('_', ' ')),
  )
      .label;

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 're_order':
        return Icons.refresh_rounded;
      case 'work_in_process':
        return Icons.hourglass_top_rounded;
      case 'order_created':
        return Icons.add_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StaffListCubit, StaffListState>(
      buildWhen: (p, c) =>
      p.isOrderUpdating(order.uuid) != c.isOrderUpdating(order.uuid) ||
          p.orderStatus(order.uuid, order.status) !=
              c.orderStatus(order.uuid, order.status) ||
          p.selectedStaffOrderIds.contains(order.id) !=
              c.selectedStaffOrderIds.contains(order.id),
      builder: (context, cubitState) {
        final currentStatus =
        cubitState.orderStatus(order.uuid, order.status);
        final isUpdating = cubitState.isOrderUpdating(order.uuid);

        return GestureDetector(
          onTap: () {},
          // => Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (_) => StaffOrderDetailPage(
          //         uuid: order.uuid, schoolId: schoolId),
          //   ),
          // ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Checkbox ──
                Padding(
                  padding: const EdgeInsets.only(top: 18, right: 10),
                  child: GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.btnColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AppTheme.btnColor : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: (order.staffPhoto != null &&
                      order.staffPhoto!.isNotEmpty)
                      ? CachedNetworkImage(
                      imageUrl: order.staffPhoto!,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(order.staffName ?? '-',
                                style: MyStyles.boldText(
                                    size: 14,
                                    color: AppTheme.black_Color),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text('• ${order.typeLabel}',
                                style: MyStyles.boldText(
                                    size: 14, color: AppTheme.btnColor),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (order.schoolName != null)
                        Text(order.schoolName!,
                            style: MyStyles.regularText(
                                size: 12,
                                color: AppTheme.graySubTitleColor),
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('#${order.id}',
                          style: MyStyles.regularText(
                              size: 12,
                              color: AppTheme.graySubTitleColor)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _statusBg(currentStatus),
                                borderRadius:
                                BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color:
                                        _statusColor(currentStatus),
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(_statusLabel(currentStatus),
                                    style: MyStyles.mediumText(
                                        size: 11,
                                        color:
                                        _statusColor(currentStatus))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 11,
                                  color: AppTheme.graySubTitleColor),
                              // const SizedBox(width: 3),
                              // Text(order.formattedOrderedAt,
                              //     style: MyStyles.regularText(
                              //         size: 11,
                              //         color: AppTheme.graySubTitleColor)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                isUpdating
                    ? const Padding(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.btnColor),
                  ),
                )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
    height: 60,
    width: 60,
    color: Colors.grey.shade300,
    child: const Icon(Icons.person, color: Colors.grey),
  );
}


class _StaffTabCountBanner extends StatefulWidget {
  final TabController tabController;
  const _StaffTabCountBanner({required this.tabController});

  @override
  State<_StaffTabCountBanner> createState() => _StaffTabCountBannerState();
}

class _StaffTabCountBannerState extends State<_StaffTabCountBanner> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.tabController.index;
    if (index == 0) {
      return BlocBuilder<StaffListCubit, StaffListState>(
        buildWhen: (p, c) => p.total != c.total,
        builder: (_, s) => _banner('Total Staff', s.total),
      );
    }
    if (index == 1) {
      return BlocBuilder<StaffCorrectionCubit, StaffCorrectionState>(
        buildWhen: (p, c) => p.total != c.total,
        builder: (_, s) => _banner('Total Corrections', s.total),
      );
    }
    if (index == 2) {
      return BlocBuilder<StaffListCubit, StaffListState>(
        buildWhen: (p, c) => p.ordersTotal != c.ordersTotal,
        builder: (_, s) => _banner('Total Orders', s.ordersTotal),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _banner(String label, int count) => Container(
    width: double.infinity,
    color: AppTheme.btnColor.withOpacity(0.08),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Text(
      '$label: $count',
      style: MyStyles.mediumText(size: 13, color: AppTheme.btnColor),
    ),
  );
}


class _StaffListDotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text =
    newValue.text.replaceAll('/', '-').replaceAll('.', '-');
    return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length));
  }
}


class _CreateOrderDialog extends StatefulWidget {
  final String schoolId;
  final List<String> studentUuids;
  final VoidCallback? onSuccess;
  const _CreateOrderDialog({
    required this.schoolId,
    this.studentUuids = const [],
    this.onSuccess,
  });

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  static const _cardTypes = [
    {'value': '', 'label': '-Select card Type-'},
    {'value': 'pvc_card', 'label': 'Pvc Card'},
    {'value': 'rfid_card', 'label': 'RFID Card'},
    {'value': 'pasting_card', 'label': 'Pasting card'},
    {'value': 'acrylic_card', 'label': 'Acrylic Card'},
    {'value': 'nfc_card', 'label': 'NFC Card'},
    {'value': 'my_fair_card', 'label': 'My Fair Card'},
  ];

  String _selectedCardType = '';
  bool _loading = false;

  Future<void> _submit(BuildContext context) async {
    if (_selectedCardType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a card type'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final cubit = context.read<StaffCorrectionCubit>();
      await cubit.createStaffOrder(
        schoolId: widget.schoolId,
        cardType: _selectedCardType,
        cardUsers: widget.studentUuids,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        final state = cubit.state;
        if (state.sendOrderError == null) {
          widget.onSuccess?.call();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.sendOrderError ?? 'Order created successfully!'),
          backgroundColor: state.sendOrderError != null ? Colors.red : AppTheme.btnColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Text('Create Order',
                    style: MyStyles.boldText(size: 18, color: AppTheme.black_Color)),
                const Spacer(),
                GestureDetector(
                  onTap: _loading ? null : () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // ── Dropdown label ──
            Text('Create Card Order For',
                style: MyStyles.mediumText(size: 13, color: AppTheme.black_Color)),
            const SizedBox(height: 10),
            // ── Card type dropdown ──
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCardType,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.graySubTitleColor),
                  style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
                  items: _cardTypes
                      .map((t) => DropdownMenuItem<String>(
                    value: t['value']!,
                    child: Text(t['label']!,
                        style: MyStyles.regularText(
                          size: 14,
                          color: t['value']!.isEmpty
                              ? AppTheme.graySubTitleColor
                              : AppTheme.black_Color,
                        )),
                  ))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _selectedCardType = v ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ── Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancel
                GestureDetector(
                  onTap: _loading ? null : () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF4E50)]),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.replay_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Cancel',
                            style: MyStyles.mediumText(size: 14, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Create
                GestureDetector(
                  onTap: _loading ? null : () => _submit(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: _loading
                          ? null
                          : const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3B2FBF)]),
                      color: _loading ? Colors.grey : null,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline,
                            size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Create',
                            style: MyStyles.mediumText(
                                size: 14, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _StaffProcessChecklistDialog extends StatefulWidget {
  final String schoolId;
  final List<String> staffUuids;
  final VoidCallback? onSuccess;

  const _StaffProcessChecklistDialog({
    required this.schoolId,
    required this.staffUuids,
    this.onSuccess,
  });

  @override
  State<_StaffProcessChecklistDialog> createState() =>
      _StaffProcessChecklistDialogState();
}

class _StaffProcessChecklistDialogState
    extends State<_StaffProcessChecklistDialog> {
  static const _listTypes = [
    {'value': '', 'label': '- Select List Type -'},
    {'value': 'selected', 'label': 'Selected Staff Correction List'},
  ];

  static const _processTypes = [
    {'value': '', 'label': '- Select Process Type -'},
    {'value': 'create', 'label': 'Create Correction List'},
    {'value': 'order', 'label': 'Order'},
  ];

  String _selectedListType = 'selected';
  String _selectedProcessType = '';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StaffCorrectionCubit, StaffCorrectionState>(
      listenWhen: (p, c) =>
      p.sendOrderLoading != c.sendOrderLoading ||
          p.sendOrderSuccess != c.sendOrderSuccess ||
          p.sendOrderError != c.sendOrderError,
      listener: (ctx, state) {
        if (!state.sendOrderLoading && state.sendOrderSuccess) {
          Navigator.of(context).pop();
          widget.onSuccess?.call();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(_selectedProcessType == 'order'
                ? 'Order processed successfully!'
                : 'Correction list created successfully!'),
            backgroundColor: AppTheme.btnColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ));
        }
        if (!state.sendOrderLoading && state.sendOrderError != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(state.sendOrderError!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ));
        }
      },
      builder: (context, state) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Process Checklist Or Orders',
                        style: MyStyles.boldText(
                            size: 16, color: AppTheme.black_Color)),
                  ),
                  GestureDetector(
                    onTap: state.sendOrderLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53)
                        ]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('List Type',
                  style: MyStyles.mediumText(
                      size: 13, color: AppTheme.black_Color)),
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedListType.isNotEmpty
                        ? AppTheme.btnColor
                        : Colors.grey.shade300,
                    width: _selectedListType.isNotEmpty ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedListType,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.graySubTitleColor),
                    style: MyStyles.regularText(
                        size: 14, color: AppTheme.black_Color),
                    items: _listTypes
                        .map((t) => DropdownMenuItem<String>(
                      value: t['value']!,
                      child: Text(t['label']!,
                          style: MyStyles.regularText(
                            size: 14,
                            color: t['value']!.isEmpty
                                ? AppTheme.graySubTitleColor
                                : AppTheme.black_Color,
                          )),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedListType = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Process Type',
                  style: MyStyles.mediumText(
                      size: 13, color: AppTheme.black_Color)),
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedProcessType.isNotEmpty
                        ? AppTheme.btnColor
                        : Colors.grey.shade300,
                    width: _selectedProcessType.isNotEmpty ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProcessType,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.graySubTitleColor),
                    style: MyStyles.regularText(
                        size: 14, color: AppTheme.black_Color),
                    items: _processTypes
                        .map((t) => DropdownMenuItem<String>(
                      value: t['value']!,
                      child: Text(t['label']!,
                          style: MyStyles.regularText(
                            size: 14,
                            color: t['value']!.isEmpty
                                ? AppTheme.graySubTitleColor
                                : AppTheme.black_Color,
                          )),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedProcessType = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: state.sendOrderLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text('Cancel',
                          style: MyStyles.mediumText(
                              size: 14, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: state.sendOrderLoading
                        ? null
                        : () {
                      if (_selectedListType.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: const Text(
                              'Please select a list type'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(12),
                        ));
                        return;
                      }
                      if (_selectedProcessType.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: const Text(
                              'Please select a process type'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(12),
                        ));
                        return;
                      }
                      context
                          .read<StaffCorrectionCubit>()
                          .processOrder(
                        schoolId: widget.schoolId,
                        staffUuids: widget.staffUuids,
                        listType: _selectedListType,
                        processType: _selectedProcessType,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: state.sendOrderLoading
                            ? Colors.grey
                            : AppTheme.btnColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: state.sendOrderLoading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : Text('Confirm',
                          style: MyStyles.mediumText(
                              size: 14, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}