import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/providers/orders/orders_state.dart';
import 'package:idmitra/screens/orders/order_detail_page.dart';
import 'package:idmitra/screens/orders/order_staff_page.dart';

class OrdersPage extends StatelessWidget {
  final String schoolId;
  final String schoolName;
  final int? totalOrderCount;
  final bool isSchool;
  const OrdersPage({
    super.key,
    required this.schoolId,
    this.schoolName = '',
    this.totalOrderCount,
    this.isSchool = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersCubit()
        ..fetchOrders(schoolId: schoolId, isSchool: isSchool)
        ..fetchSchoolClasses(schoolId)
        ..fetchStaffOrdersTotal(schoolId: schoolId),
      child: Builder(
        builder: (_) => _OrdersView(
          schoolId: schoolId,
          schoolName: schoolName,
          totalOrderCount: totalOrderCount,
          isSchool: isSchool,
        ),
      ),
    );
  }
}

class _OrdersView extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final int? totalOrderCount;
  final bool isSchool;
  const _OrdersView({
    required this.schoolId,
    this.schoolName = '',
    this.totalOrderCount,
    this.isSchool = false,
  });

  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _dateFromCtrl = TextEditingController();
  final TextEditingController _dateToCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  String _selectedStatus = '';
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<OrdersCubit>().fetchOrders(
          isLoadMore: true,
          search: _searchCtrl.text.trim(),
          status: _selectedStatus,
          classId: _selectedClass,
          schoolId: widget.schoolId,
          isSchool: widget.isSchool,
          dateFrom: _dateFromCtrl.text,
          dateTo: _dateToCtrl.text,
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
    context.read<OrdersCubit>().fetchOrders(
      search: _searchCtrl.text.trim(),
      status: _selectedStatus,
      classId: _selectedClass,
      schoolId: widget.schoolId,
      isSchool: widget.isSchool,
      dateFrom: _dateFromCtrl.text,
      dateTo: _dateToCtrl.text,
    );
  }

  bool get _hasActiveFilters =>
      _selectedStatus.isNotEmpty ||
          _selectedClass.isNotEmpty ||
          _dateFromCtrl.text.isNotEmpty ||
          _dateToCtrl.text.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _selectedStatus = '';
      _selectedClass = '';
      _dateFromCtrl.clear();
      _dateToCtrl.clear();
    });
    _resetAndFetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: 'Orders',
        backgroundColor: Colors.white,
        showText: true,
        showDivider: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: BlocBuilder<OrdersCubit, OrdersState>(
              buildWhen: (p, c) => p.staffTotal != c.staffTotal || p.staffTotalLoading != c.staffTotalLoading,
              builder: (_, state) => TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => OrdersCubit(),
                      child: OrderStaffPage(schoolId: widget.schoolId),
                    ),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined, size: 15),
                label: Text(
                  state.staffTotalLoading
                      ? 'Staff'
                      : state.staffTotal > 0
                          ? 'Staff (${state.staffTotal})'
                          : 'Staff',
                  style: MyStyles.mediumText(size: 12, color: AppTheme.btnColor),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.btnColor,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
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
                Row(
                  children: [
                    Expanded(child: _classDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _statusDropdown()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(_dateFromCtrl, 'From dd-mm-yyyy'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _dateField(_dateToCtrl, 'To dd-mm-yyyy')),
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.lightRedColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close,
                              size: 12,
                              color: AppTheme.cancelTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear Filters',
                              style: MyStyles.mediumText(
                                size: 11,
                                color: AppTheme.cancelTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // List
          Expanded(
            child: BlocBuilder<OrdersCubit, OrdersState>(
              builder: (_, state) {
                if (state.loading && state.ordersList.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: OrderListShimmer(),
                  );
                }
                if (state.error != null && state.ordersList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          style: MyStyles.regularText(
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _resetAndFetch,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.btnColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (state.ordersList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/no_data.png',
                          height: 160,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No orders found',
                          style: MyStyles.mediumText(
                            size: 14,
                            color: AppTheme.graySubTitleColor,
                          ),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _clearFilters,
                            child: Text(
                              'Clear filters',
                              style: MyStyles.mediumText(
                                size: 13,
                                color: AppTheme.btnColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppTheme.btnColor,
                  onRefresh: () async => _resetAndFetch(),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount:
                    state.ordersList.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i < state.ordersList.length) {
                        return _OrderCard(
                          order: state.ordersList[i],
                          schoolId: widget.schoolId,
                          isSchool: widget.isSchool,
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.btnColor,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
    onChanged: (_) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _resetAndFetch);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.appBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintText: 'Search by student name, order ID...',
      prefixIcon: const Icon(
        Icons.search_rounded,
        size: 20,
        color: AppTheme.graySubTitleColor,
      ),
      suffixIcon: _searchCtrl.text.isNotEmpty
          ? GestureDetector(
        onTap: () {
          _searchCtrl.clear();
          setState(() {});
          _resetAndFetch();
        },
        child: const Icon(
          Icons.close,
          size: 16,
          color: AppTheme.graySubTitleColor,
        ),
      )
          : null,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.backBtnBgColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.btnColor),
        borderRadius: BorderRadius.circular(12),
      ),
      hintStyle: MyStyles.regularText(
        size: 13,
        color: AppTheme.graySubTitleColor,
      ),
    ),
  );

  Widget _classDropdown() => BlocBuilder<OrdersCubit, OrdersState>(
    buildWhen: (p, c) =>
    p.availableClasses != c.availableClasses ||
        p.classesLoading != c.classesLoading,
    builder: (_, state) {
      return _dropdown(
        value: _selectedClass.isEmpty ? '' : _selectedClass,
        hint: 'All Classes',
        loading: state.classesLoading,
        items: [
          const DropdownMenuItem(value: '', child: Text('All Classes')),
          ...state.availableClasses.map((c) {
            final clsName = c.nameWithprefix ?? c.name;
            final displayName = c.sectionName.isNotEmpty
                ? '$clsName (${c.sectionName})'
                : clsName;
            final itemValue = c.sectionId != null
                ? '${c.classId}_${c.sectionId}'
                : c.classId.toString();
            return DropdownMenuItem(
              value: itemValue,
              child: Text(displayName, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: (v) {
          setState(() => _selectedClass = v ?? '');
          WidgetsBinding.instance.addPostFrameCallback((_) => _resetAndFetch());
        },
      );
    },
  );

  Widget _statusDropdown() => _dropdown(
    value: _selectedStatus,
    hint: 'All Status',
    items: kOrderFilterStatuses
        .map(
          (s) => DropdownMenuItem<String>(
        value: s.value,
        child: Text(s.label, overflow: TextOverflow.ellipsis),
      ),
    )
        .toList(),
    onChanged: (v) {
      setState(() => _selectedStatus = v ?? '');
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetAndFetch());
    },
  );

  Widget _dropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool loading = false,
  }) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppTheme.appBackgroundColor,
      border: Border.all(color: AppTheme.backBtnBgColor.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        menuMaxHeight: 300,
        icon: loading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.btnColor,
          ),
        )
            : const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: AppTheme.graySubTitleColor,
        ),
        style: MyStyles.regularText(size: 13, color: AppTheme.black_Color),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _dateField(TextEditingController ctrl, String hint) {
    return StatefulBuilder(
      builder: (context, setLocal) => AppTextField(
        controller: ctrl,
        hintText: hint,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.\-/]')),
          LengthLimitingTextInputFormatter(10),
          _DotDateFormatter(),
        ],
        suffixIcon: ctrl.text.isNotEmpty
            ? GestureDetector(
          onTap: () {
            ctrl.clear();
            setLocal(() {});
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 200),
              _resetAndFetch,
            );
          },
          child: const Icon(Icons.close, size: 16),
        )
            : null,
        onChanged: (_) {
          setLocal(() {});
          if (ctrl.text.length == 10 || ctrl.text.isEmpty) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 400),
              _resetAndFetch,
            );
          }
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final OrderModel order;
  final String schoolId;
  final bool isSchool;
  const _OrderCard({
    required this.order,
    this.schoolId = '',
    this.isSchool = false,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late String _currentStatus;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Color get _statusColor {
    switch (_currentStatus) {
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

  Color get _statusBg {
    switch (_currentStatus) {
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

  String get _statusLabel {
    return kOrderStatuses
        .firstWhere(
          (s) => s.value == _currentStatus,
      orElse: () => OrderStatusOption(
        _currentStatus,
        _currentStatus.replaceAll('_', ' '),
      ),
    )
        .label;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    final success = await context.read<OrdersCubit>().updateOrderStatus(
      widget.order.uuid,
      newStatus,
    );
    if (mounted) {
      setState(() {
        _updating = false;
        if (success) _currentStatus = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Status updated successfully' : 'Failed to update status',
          ),
          backgroundColor: success ? AppTheme.btnColor : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.order.student;
    final school = widget.order.school;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(uuid: widget.order.uuid),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child:
              (student?.profilePhotoUrl != null &&
                  student!.profilePhotoUrl!.isNotEmpty)
                  ? Image.network(
                student.profilePhotoUrl!,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
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
                        child: Text(
                          student?.name ?? '-',
                          style: MyStyles.boldText(
                            size: 16,
                            color: AppTheme.black_Color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (student?.className != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '• ${student!.className!}',
                            style: MyStyles.boldText(
                              size: 14,
                              color: AppTheme.btnColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // School name
                  if (school?.name != null)
                    Text(
                      school!.name,
                      style: MyStyles.regularText(
                        size: 12,
                        color: AppTheme.graySubTitleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
                  // Order info row
                  Row(
                    children: [
                      // Text(
                      //   '#${widget.order.id} • ${widget.order.typeLabel}',
                      //   style: MyStyles.regularText(
                      //     size: 12,
                      //     color: AppTheme.graySubTitleColor,
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel,
                              style: MyStyles.mediumText(
                                size: 11,
                                color: _statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 11,
                        color: AppTheme.graySubTitleColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.order.orderedAt,
                        style: MyStyles.regularText(
                          size: 11,
                          color: AppTheme.graySubTitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _updating
                ? const Padding(
              padding: EdgeInsets.all(4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.btnColor,
                ),
              ),
            )
                : _currentStatus == 'completed'
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              offset: const Offset(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              onSelected: _updateStatus,
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: 'completed',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppTheme.graySubTitleColor,
                      ),
                      SizedBox(width: 10),
                      Text('Mark as Completed'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 60,
    width: 60,
    color: Colors.grey.shade300,
    child: const Icon(Icons.person, color: Colors.grey),
  );
}

class _DotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll('/', '-').replaceAll('.', '-');
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}