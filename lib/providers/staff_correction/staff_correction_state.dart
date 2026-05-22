import 'package:idmitra/models/staff/StaffListModel.dart';

class StaffDownloadColumn {
  final String key;
  final String label;
  const StaffDownloadColumn({required this.key, required this.label});
}

class StaffCorrectionItem {
  final int id;
  final String? uuid;
  final String? status;
  final String? remark;
  final StaffListModel? staff;
  final StaffListModel? oldData;

  StaffListModel? get effectiveStaff => staff ?? oldData;

  const StaffCorrectionItem({
    required this.id,
    this.uuid,
    this.status,
    this.remark,
    this.staff,
    this.oldData,
  });

  factory StaffCorrectionItem.fromJson(Map<String, dynamic> json) {
    final staffJson = json['staff'] as Map<String, dynamic>?;
    final oldDataJson = json['old_data'] as Map<String, dynamic>?;
    return StaffCorrectionItem(
      id: json['id'] ?? 0,
      uuid: json['uuid'],
      status: json['status'],
      remark: json['remark'],
      staff: staffJson != null ? StaffListModel.fromJson(staffJson) : null,
      oldData: oldDataJson != null ? StaffListModel.fromJson(oldDataJson) : null,
    );
  }
}

class StaffCorrectionState {
  final bool loading;
  final List<StaffCorrectionItem> items;
  final int page;
  final bool hasMore;
  final int total;
  final String? error;
  final Set<int> selectedIds;
  final bool sendOrderLoading;
  final bool sendOrderSuccess;
  final String? sendOrderError;
  final bool columnsLoading;
  final List<StaffDownloadColumn> downloadColumns;

  const StaffCorrectionState({
    this.loading = false,
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.total = 0,
    this.error,
    this.selectedIds = const {},
    this.sendOrderLoading = false,
    this.sendOrderSuccess = false,
    this.sendOrderError,
    this.columnsLoading = false,
    this.downloadColumns = const [],
  });

  StaffCorrectionState copyWith({
    bool? loading,
    List<StaffCorrectionItem>? items,
    int? page,
    bool? hasMore,
    int? total,
    String? error,
    bool? clearError,
    Set<int>? selectedIds,
    bool? sendOrderLoading,
    bool? sendOrderSuccess,
    String? sendOrderError,
    bool? clearSendOrderError,
    bool? columnsLoading,
    List<StaffDownloadColumn>? downloadColumns,
  }) {
    return StaffCorrectionState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      error: clearError == true ? null : (error ?? this.error),
      selectedIds: selectedIds ?? this.selectedIds,
      sendOrderLoading: sendOrderLoading ?? this.sendOrderLoading,
      sendOrderSuccess: sendOrderSuccess ?? this.sendOrderSuccess,
      sendOrderError: clearSendOrderError == true ? null : (sendOrderError ?? this.sendOrderError),
      columnsLoading: columnsLoading ?? this.columnsLoading,
      downloadColumns: downloadColumns ?? this.downloadColumns,
    );
  }
}
