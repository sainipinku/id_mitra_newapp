import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/orders/OrderModel.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String uuid;
  final String schoolId;
  const AdminOrderDetailPage({super.key, required this.uuid, this.schoolId = ''});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  OrderModel? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = Config.baseUrl + Routes.getOrderDetail(widget.uuid, schoolId: widget.schoolId);
      final response = await ApiManager().getRequest(url);
      if (response == null) {
        setState(() {
          _loading = false;
          _error = 'Failed to load order';
        });
        return;
      }
      final json = jsonDecode(response.body);
      final raw = json['data'];
      Map<String, dynamic>? orderMap;
      if (raw is Map<String, dynamic>) {
        orderMap = raw.containsKey('id') ? raw : (raw['order'] as Map<String, dynamic>?);
      }
      if (orderMap == null) {
        setState(() { _loading = false; _error = 'Invalid response format'; });
        return;
      }
      setState(() {
        _loading = false;
        _order = OrderModel.fromJson(orderMap!);
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: 'Order Details',
        backgroundColor: Colors.white,
        showText: true,
      ),
      body: _loading
          ? const OrderDetailShimmer()
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: MyStyles.regularText(
                          size: 14, color: Colors.red)))
              : _order == null
                  ? Center(
                      child: Image.asset('assets/images/no_data.png',
                          height: 200))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _headerCard(),
                            const SizedBox(height: 12),
                            _sectionCard(
                              icon: Icons.receipt_long_outlined,
                              title: 'Order Information',
                              rows: _orderRows(),
                            ),
                            const SizedBox(height: 12),
                            if (_order!.student != null)
                              _sectionCard(
                                icon: Icons.person_outline_rounded,
                                title: 'Student Information',
                                rows: _studentRows(),
                              ),
                            if (_order!.student != null)
                              const SizedBox(height: 12),
                            if (_order!.school != null)
                              _sectionCard(
                                icon: Icons.school_outlined,
                                title: 'School Information',
                                rows: _schoolRows(),
                              ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _headerCard() {
    final o = _order!;
    final student = o.student;
    final hasPhoto = student?.profilePhotoUrl?.isNotEmpty ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.btnColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.btnColor.withOpacity(0.15),
                  AppTheme.mainColor.withOpacity(0.08)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
            child: Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.btnColor.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.appBackgroundColor,
                      backgroundImage: hasPhoto
                          ? NetworkImage(student!.profilePhotoUrl!)
                          : null,
                      child: !hasPhoto
                          ? Icon(Icons.person_rounded,
                              size: 36,
                              color: AppTheme.graySubTitleColor)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('#${o.id}',
                      style: MyStyles.boldText(
                          size: 16, color: AppTheme.black_Color)),
                  if (student != null) ...[
                    const SizedBox(height: 2),
                    Text(student.name,
                        style: MyStyles.mediumText(
                            size: 14, color: AppTheme.black_Color)),
                    if (student.className != null) ...[
                      const SizedBox(height: 2),
                      Text(student.className!,
                          style: MyStyles.regularText(
                              size: 12, color: AppTheme.btnColor)),
                    ],
                  ],
                  const SizedBox(height: 4),
                  Text(o.typeLabel,
                      style: MyStyles.regularText(
                          size: 13, color: AppTheme.graySubTitleColor)),
                  const SizedBox(height: 4),
                  Text(o.orderedAt,
                      style: MyStyles.regularText(
                          size: 12, color: AppTheme.graySubTitleColor)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppTheme.btnColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(o.statusLabel,
                        style: MyStyles.mediumText(
                            size: 12, color: AppTheme.btnColor)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<_AdminRow> rows,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.btnColor.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: AppTheme.btnColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(icon, size: 14, color: AppTheme.btnColor),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: MyStyles.boldText(
                        size: 13, color: AppTheme.black_Color)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.LineColor),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: List.generate(
                rows.length,
                (i) => Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(rows[i].label,
                            style: MyStyles.regularText(
                                size: 12,
                                color: AppTheme.graySubTitleColor)),
                        Flexible(
                          child: Text(rows[i].value,
                              style: MyStyles.mediumText(
                                  size: 13, color: AppTheme.black_Color),
                              textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                    if (i < rows.length - 1)
                      Divider(height: 16, color: AppTheme.LineColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_AdminRow> _orderRows() {
    final o = _order!;
    return [
      _AdminRow('Order ID', '#${o.id}'),
      _AdminRow('Type', o.typeLabel),
      _AdminRow('Status', o.statusLabel),
      _AdminRow('Order Date', o.formattedOrderedAt),
      _AdminRow('Received At', o.receivedAtShort),
      if (o.studentCard == 1)
        _AdminRow('Student Card', 'Yes (Qty: ${o.studentCardQty})'),
      if (o.parentCard == 1) _AdminRow('Parent Card', 'Yes'),
      if (o.admitCard == 1) _AdminRow('Admit Card', 'Yes'),
      if (o.printingIssue != null)
        _AdminRow('Printing Issue', o.printingIssue!),
      if (o.deliveredAt != null) _AdminRow('Delivered At', o.deliveredAt!),
      if (o.cancelledAt != null)
        _AdminRow('Cancelled At', o.cancelledAt!),
    ].where((r) => r.value.isNotEmpty).toList();
  }

  List<_AdminRow> _studentRows() {
    final s = _order!.student!;
    return [
      _AdminRow('Name', s.name),
      if (s.className != null) _AdminRow('Class', s.className!),
      if (s.sectionName != null) _AdminRow('Section', s.sectionName!),
      if (s.gender != null) _AdminRow('Gender', _cap(s.gender!)),
      if (s.dob != null) _AdminRow('Date of Birth', s.dob!),
      if (s.fatherName != null) _AdminRow('Father Name', s.fatherName!),
      if (s.fatherPhone != null)
        _AdminRow('Father Phone', s.fatherPhone!),
      if (s.motherName != null) _AdminRow('Mother Name', s.motherName!),
      if (s.address != null) _AdminRow('Address', s.address!),
      if (s.pincode != null) _AdminRow('Pincode', s.pincode!),
      if (s.loginId != null) _AdminRow('Login ID', s.loginId!),
    ].where((r) => r.value.isNotEmpty).toList();
  }

  List<_AdminRow> _schoolRows() {
    final sc = _order!.school!;
    return [
      _AdminRow('School Name', sc.name),
      if (sc.prefix != null) _AdminRow('Prefix', sc.prefix!),
      if (sc.address != null) _AdminRow('Address', sc.address!),
      if (sc.pincode != null) _AdminRow('Pincode', sc.pincode!),
    ].where((r) => r.value.isNotEmpty).toList();
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _AdminRow {
  final String label;
  final String value;
  const _AdminRow(this.label, this.value);
}
