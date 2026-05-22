import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/screens/staff/staff_order_page/staff_order_detail_page.dart';

class OrderStaffItem {
  final int id;
  final String uuid;
  final String status;
  final String type;
  final String orderedAt;
  final String? staffName;
  final String? staffPhoto;
  final String? schoolName;

  const OrderStaffItem({
    required this.id,
    required this.uuid,
    required this.status,
    required this.type,
    required this.orderedAt,
    this.staffName,
    this.staffPhoto,
    this.schoolName,
  });

  factory OrderStaffItem.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] as Map<String, dynamic>?;
    final school = json['school'] as Map<String, dynamic>?;
    return OrderStaffItem(
      id: json['id'] ?? 0,
      uuid: json['uuid'] ?? '',
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      orderedAt: json['orderd_at'] ?? json['created_at'] ?? '',
      staffName: staff?['name'],
      staffPhoto: staff?['profile_photo_url'],
      schoolName: school?['name'],
    );
  }

  String get statusLabel => kOrderStatuses
      .firstWhere((s) => s.value == status,
          orElse: () => OrderStatusOption(status, status.replaceAll('_', ' ')))
      .label;

  String get typeLabel {
    switch (type) {
      case 'pvc_card': return 'PVC Card';
      case 'rfid_card': return 'RFID Card';
      case 'pasting_card': return 'Pasting Card';
      default: return type.replaceAll('_', ' ');
    }
  }

  Color get statusColor {
    switch (status) {
      case 'completed': return const Color(0xFF2DC24E);
      case 'cancelled': return AppTheme.cancelTextColor;
      case 'work_in_process': return AppTheme.btnColor;
      case 're_order': return AppTheme.PendingDotColor;
      default: return AppTheme.graySubTitleColor;
    }
  }

  Color get statusBg {
    switch (status) {
      case 'completed': return const Color(0xFFE8F9ED);
      case 'cancelled': return AppTheme.lightRedColor;
      case 'work_in_process': return AppTheme.lightBlueColor;
      case 're_order': return AppTheme.PendingLightColor;
      default: return AppTheme.appBackgroundColor;
    }
  }
}

class OrderStaffPage extends StatefulWidget {
  final String schoolId;
  const OrderStaffPage({super.key, required this.schoolId});

  @override
  State<OrderStaffPage> createState() => _OrderStaffPageState();
}

class _OrderStaffPageState extends State<OrderStaffPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _dateFromCtrl = TextEditingController();
  final TextEditingController _dateToCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<OrderStaffItem> _orders = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;
  String? _error;
  String _selectedStatus = '';

  bool get _hasActiveFilters =>
      _selectedStatus.isNotEmpty ||
      _dateFromCtrl.text.isNotEmpty ||
      _dateToCtrl.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _fetch(reset: true);
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
    setState(() {
      _orders = [];
      _page = 1;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    _fetch(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = '';
      _dateFromCtrl.clear();
      _dateToCtrl.clear();
    });
    _resetAndFetch();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentPage = reset ? 1 : _page;
      var url = '${Config.baseUrl}auth/school/${widget.schoolId}/staff/orders?page=$currentPage';
      if (_selectedStatus.isNotEmpty) url += '&status=$_selectedStatus';
      if (_searchCtrl.text.trim().isNotEmpty) url += '&search=${_searchCtrl.text.trim()}';
      if (_dateFromCtrl.text.isNotEmpty) url += '&start_date=${_dateFromCtrl.text}';
      if (_dateToCtrl.text.isNotEmpty) url += '&end_date=${_dateToCtrl.text}';

      final response = await ApiManager().getRequest(url);
      if (response == null) {
        setState(() { _loading = false; _error = 'Failed to load orders'; });
        return;
      }
      
      print('StaffOrders API URL: $url');
      print('StaffOrders Response Status: ${response.statusCode}');
      print('StaffOrders Response Body: ${response.body}');
      
      final json = jsonDecode(response.body);
      
      final isSuccess = (json['status'] == true || json['status'] == 'success' || json['success'] == true);
      
      if (!isSuccess) {
        setState(() { 
          _loading = false; 
          _error = json['message'] ?? 'Failed to load staff orders'; 
        });
        return;
      }
      
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        setState(() { _loading = false; _error = 'Invalid response format'; });
        return;
      }

      List rawList = [];
      int total = 0;
      int lastPage = 1;
      int respCurrentPage = 1;
      
      if (data.containsKey('list') && data['list'] is Map) {
        final listData = data['list'] as Map<String, dynamic>;
        rawList = listData['data'] ?? [];
        total = listData['total'] ?? 0;
        lastPage = listData['last_page'] ?? 1;
        respCurrentPage = listData['current_page'] ?? 1;
      } 
      else if (data.containsKey('data') && data['data'] is List) {
        rawList = data['data'] as List;
        total = data['total'] ?? rawList.length;
        lastPage = data['last_page'] ?? 1;
        respCurrentPage = data['current_page'] ?? 1;
      }
      else if (data.containsKey('orders')) {
        final ordersData = data['orders'];
        if (ordersData is List) {
          rawList = ordersData;
          total = rawList.length;
        } else if (ordersData is Map) {
          rawList = ordersData['data'] ?? [];
          total = ordersData['total'] ?? 0;
          lastPage = ordersData['last_page'] ?? 1;
          respCurrentPage = ordersData['current_page'] ?? 1;
        }
      }

      print('Parsed rawList length: ${rawList.length}');
      print('Total: $total, Current Page: $respCurrentPage, Last Page: $lastPage');

      final newOrders = rawList.map((e) => OrderStaffItem.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _loading = false;
        _total = total;
        _page = respCurrentPage + 1;
        _hasMore = respCurrentPage < lastPage;
        _orders = reset ? newOrders : [..._orders, ...newOrders];
      });
    } catch (e, stackTrace) {
      print('StaffOrders Error: $e');
      print('StackTrace: $stackTrace');
      setState(() { _loading = false; _error = 'Error: ${e.toString()}'; });
    }
  }

  void _loadMore() {
    if (!_loading && _hasMore) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: 'Staff Card Orders',
        backgroundColor: Colors.white,
        showText: true,
        showDivider: true,
        actions: [],
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
                _statusDropdown(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _dateField(_dateFromCtrl, 'From dd-mm-yyyy')),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.lightRedColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, size: 12, color: AppTheme.cancelTextColor),
                            const SizedBox(width: 4),
                            Text('Clear Filters', style: MyStyles.mediumText(size: 11, color: AppTheme.cancelTextColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (!_loading && _total > 0)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.btnColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 14, color: AppTheme.btnColor),
                    const SizedBox(width: 6),
                    Text('Total: $_total', style: MyStyles.mediumText(size: 12, color: AppTheme.btnColor)),
                  ],
                ),
              ),
            ),

          // List
          Expanded(
            child: _error != null && _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _error!,
                                style: MyStyles.regularText(size: 14, color: Colors.red),
                                textAlign: TextAlign.center,
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/no_data.png', height: 160),
                                const SizedBox(height: 12),
                                Text('No staff orders found',
                                    style: MyStyles.mediumText(size: 14, color: AppTheme.graySubTitleColor)),
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
                          )
                        : RefreshIndicator(
                            color: AppTheme.btnColor,
                            onRefresh: () async => _resetAndFetch(),
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              itemCount: _orders.length + (_hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i < _orders.length) return _StaffOrderCard(order: _orders[i], schoolId: widget.schoolId);
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: CircularProgressIndicator(color: AppTheme.btnColor, strokeWidth: 2)),
                                );
                              },
                            ),
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
          hintText: 'Search staff orders...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.graySubTitleColor),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.backBtnBgColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppTheme.btnColor),
            borderRadius: BorderRadius.circular(12),
          ),
          hintStyle: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor),
        ),
      );

  Widget _statusDropdown() => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.appBackgroundColor,
          border: Border.all(color: AppTheme.backBtnBgColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedStatus,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.graySubTitleColor),
            style: MyStyles.regularText(size: 13, color: AppTheme.black_Color),
            items: kOrderFilterStatuses
                .map((s) => DropdownMenuItem<String>(
                      value: s.value,
                      child: Text(s.label, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedStatus = v ?? '');
              _resetAndFetch();
            },
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
                  _debounce = Timer(const Duration(milliseconds: 200), _resetAndFetch);
                },
                child: const Icon(Icons.close, size: 16),
              )
            : null,
        onChanged: (_) {
          setLocal(() {});
          if (ctrl.text.length == 10 || ctrl.text.isEmpty) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _resetAndFetch);
          }
        },
      ),
    );
  }
}


class _StaffOrderCard extends StatefulWidget {
  final OrderStaffItem order;
  final String schoolId;
  const _StaffOrderCard({required this.order, required this.schoolId});

  @override
  State<_StaffOrderCard> createState() => _StaffOrderCardState();
}

class _StaffOrderCardState extends State<_StaffOrderCard> {
  late String _currentStatus;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Color get _statusColor {
    switch (_currentStatus) {
      case 'completed': return const Color(0xFF2DC24E);
      case 'cancelled': return AppTheme.cancelTextColor;
      case 'work_in_process': return AppTheme.btnColor;
      case 're_order': return AppTheme.PendingDotColor;
      default: return AppTheme.graySubTitleColor;
    }
  }

  Color get _statusBg {
    switch (_currentStatus) {
      case 'completed': return const Color(0xFFE8F9ED);
      case 'cancelled': return AppTheme.lightRedColor;
      case 'work_in_process': return AppTheme.lightBlueColor;
      case 're_order': return AppTheme.PendingLightColor;
      default: return AppTheme.appBackgroundColor;
    }
  }

  String get _statusLabel => kOrderStatuses
      .firstWhere((s) => s.value == _currentStatus,
          orElse: () => OrderStatusOption(_currentStatus, _currentStatus.replaceAll('_', ' ')))
      .label;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      final cubit = context.read<OrdersCubit>();
      final success = await cubit.updateOrderStatus(widget.order.uuid, newStatus);
      if (!mounted) return;
      if (success) {
        setState(() {
          _updating = false;
          _currentStatus = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Order status updated successfully'),
          backgroundColor: AppTheme.btnColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      } else {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      print('StaffOrder updateStatus error: $e');
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffOrderDetailPage(uuid: widget.order.uuid, schoolId: widget.schoolId),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: (widget.order.staffPhoto != null && widget.order.staffPhoto!.isNotEmpty)
                ? Image.network(
                    widget.order.staffPhoto!,
                    height: 60, width: 60, fit: BoxFit.cover,
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
                        widget.order.staffName ?? '-',
                        style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '• ${widget.order.typeLabel}',
                        style: MyStyles.boldText(size: 14, color: AppTheme.btnColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (widget.order.schoolName != null)
                  Text(
                    widget.order.schoolName!,
                    style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 3),
                Text(
                  '#${widget.order.id}',
                  style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(_statusLabel, style: MyStyles.mediumText(size: 11, color: _statusColor)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.graySubTitleColor),
                    const SizedBox(width: 3),
                    // Text(widget.order.formattedOrderedAt,
                    //     style: MyStyles.regularText(size: 11, color: AppTheme.graySubTitleColor)),
                  ],
                ),
              ],
            ),
          ),

          _updating
              ? const Padding(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.btnColor),
                  ),
                )
              : _currentStatus == 'completed'
                  ? const SizedBox.shrink()
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      offset: const Offset(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      onSelected: _updateStatus,
                      itemBuilder: (_) => [
                        const PopupMenuItem<String>(
                          value: 'completed',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: AppTheme.graySubTitleColor),
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
        height: 60, width: 60,
        color: Colors.grey.shade300,
        child: const Icon(Icons.person, color: Colors.grey),
      );
}

class _DotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '-').replaceAll('.', '-');
    return newValue.copyWith(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
