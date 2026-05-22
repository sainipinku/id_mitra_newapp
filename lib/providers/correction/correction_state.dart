import 'package:idmitra/models/correction/CorrectionListModel.dart';

class DownloadColumn {
  final String key;
  final String label;
  const DownloadColumn({required this.key, required this.label});
}

class CorrectionState {
  final bool loading;
  final List<CorrectionItem> items;
  final int page;
  final bool hasMore;
  final String? error;
  final Set<int> selectedIds;
  final bool sendOrderLoading;
  final bool sendOrderSuccess;
  final String? sendOrderError;
  final String? sendOrderMessage;
  final bool createOrderLoading;
  final bool createOrderSuccess;
  final String? createOrderError;
  final bool syncSuccess;
  final bool downloadLoading;
  final String? downloadUrl;
  final String? downloadError;
  final bool columnsLoading;
  final List<DownloadColumn> downloadColumns;

  final bool studentsLoading;
  final List<CorrectionStudentItem> students;
  final int studentsPage;
  final bool studentsHasMore;
  final String? studentsError;
  final Set<int> selectedStudentIds;
  final List<String> selectedClassIds;
  final int studentsTotal;

  const CorrectionState({
    this.loading = false,
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.error,
    this.selectedIds = const {},
    this.sendOrderLoading = false,
    this.sendOrderSuccess = false,
    this.sendOrderError,
    this.sendOrderMessage,
    this.createOrderLoading = false,
    this.createOrderSuccess = false,
    this.createOrderError,
    this.syncSuccess = false,
    this.downloadLoading = false,
    this.downloadUrl,
    this.downloadError,
    this.columnsLoading = false,
    this.downloadColumns = const [],
    this.studentsLoading = false,
    this.students = const [],
    this.studentsPage = 1,
    this.studentsHasMore = true,
    this.studentsError,
    this.selectedStudentIds = const {},
    this.selectedClassIds = const [],
    this.studentsTotal = 0,
  });

  CorrectionState copyWith({
    bool? loading,
    List<CorrectionItem>? items,
    int? page,
    bool? hasMore,
    String? error,
    bool? clearError,
    Set<int>? selectedIds,
    bool? sendOrderLoading,
    bool? sendOrderSuccess,
    String? sendOrderError,
    String? sendOrderMessage,
    bool? clearSendOrderError,
    bool? clearSendOrderMessage,
    bool? createOrderLoading,
    bool? createOrderSuccess,
    String? createOrderError,
    bool? clearCreateOrderError,
    bool? syncSuccess,
    bool? downloadLoading,
    String? downloadUrl,
    String? downloadError,
    bool? clearDownloadError,
    bool? clearDownloadUrl,
    bool? columnsLoading,
    List<DownloadColumn>? downloadColumns,
    bool? studentsLoading,
    List<CorrectionStudentItem>? students,
    int? studentsPage,
    bool? studentsHasMore,
    String? studentsError,
    bool? clearStudentsError,
    Set<int>? selectedStudentIds,
    List<String>? selectedClassIds,
    int? studentsTotal,
  }) {
    return CorrectionState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      error: clearError == true ? null : (error ?? this.error),
      selectedIds: selectedIds ?? this.selectedIds,
      sendOrderLoading: sendOrderLoading ?? this.sendOrderLoading,
      sendOrderSuccess: sendOrderSuccess ?? this.sendOrderSuccess,
      sendOrderError: clearSendOrderError == true ? null : (sendOrderError ?? this.sendOrderError),
      sendOrderMessage: clearSendOrderMessage == true ? null : (sendOrderMessage ?? this.sendOrderMessage),
      createOrderLoading: createOrderLoading ?? this.createOrderLoading,
      createOrderSuccess: createOrderSuccess ?? this.createOrderSuccess,
      createOrderError: clearCreateOrderError == true ? null : (createOrderError ?? this.createOrderError),
      syncSuccess: syncSuccess ?? this.syncSuccess,
      downloadLoading: downloadLoading ?? this.downloadLoading,
      downloadUrl: clearDownloadUrl == true ? null : (downloadUrl ?? this.downloadUrl),
      downloadError: clearDownloadError == true ? null : (downloadError ?? this.downloadError),
      columnsLoading: columnsLoading ?? this.columnsLoading,
      downloadColumns: downloadColumns ?? this.downloadColumns,
      studentsLoading: studentsLoading ?? this.studentsLoading,
      students: students ?? this.students,
      studentsPage: studentsPage ?? this.studentsPage,
      studentsHasMore: studentsHasMore ?? this.studentsHasMore,
      studentsError: clearStudentsError == true ? null : (studentsError ?? this.studentsError),
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      selectedClassIds: selectedClassIds ?? this.selectedClassIds,
      studentsTotal: studentsTotal ?? this.studentsTotal,
    );
  }
}
