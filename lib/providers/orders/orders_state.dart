import 'package:idmitra/models/orders/OrderModel.dart';

class OrdersState {
  final bool loading;
  final bool isPaginationLoading;
  final List<OrderModel> ordersList;
  final int page;
  final bool hasMore;
  final int total;
  final String? error;
  final bool statsLoading;
  final int staffTotal;
  final bool staffTotalLoading;
  final List<OrderClass> availableClasses;
  final bool classesLoading;
  final String schoolId;
  final List<SchoolOrderClass> schoolClassesWithSections;
  final Set<String> selectedOrderUuids;

  const OrdersState({
    this.loading = false,
    this.isPaginationLoading = false,
    this.ordersList = const [],
    this.page = 1,
    this.hasMore = true,
    this.total = 0,
    this.error,
    this.statsLoading = false,
    this.staffTotal = 0,
    this.staffTotalLoading = false,
    this.availableClasses = const [],
    this.classesLoading = true,
    this.schoolId = '',
    this.schoolClassesWithSections = const [],
    this.selectedOrderUuids = const {},
  });

  OrdersState copyWith({
    bool? loading,
    bool? isPaginationLoading,
    List<OrderModel>? ordersList,
    int? page,
    bool? hasMore,
    int? total,
    String? error,
    bool? clearError,
    bool? statsLoading,
    int? staffTotal,
    bool? staffTotalLoading,
    List<OrderClass>? availableClasses,
    bool? classesLoading,
    String? schoolId,
    List<SchoolOrderClass>? schoolClassesWithSections,
    Set<String>? selectedOrderUuids,
  }) {
    return OrdersState(
      loading: loading ?? this.loading,
      isPaginationLoading: isPaginationLoading ?? this.isPaginationLoading,
      ordersList: ordersList ?? this.ordersList,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      error: (clearError == true) ? null : (error ?? this.error),
      statsLoading: statsLoading ?? this.statsLoading,
      staffTotal: staffTotal ?? this.staffTotal,
      staffTotalLoading: staffTotalLoading ?? this.staffTotalLoading,
      availableClasses: availableClasses ?? this.availableClasses,
      classesLoading: classesLoading ?? this.classesLoading,
      schoolId: schoolId ?? this.schoolId,
      schoolClassesWithSections: schoolClassesWithSections ?? this.schoolClassesWithSections,
      selectedOrderUuids: selectedOrderUuids ?? this.selectedOrderUuids,
    );
  }
}

class OrderClass {
  final int classId;
  final int? sectionId;
  final String name;
  final String? nameWithprefix;
  final String sectionName;

  const OrderClass({
    required this.classId,
    this.sectionId,
    required this.name,
    this.nameWithprefix,
    this.sectionName = '',
  });
}

/// Used for school-specific orders endpoint classes_with_sections
class SchoolOrderClass {
  final String value; // e.g. "2486-1246"
  final String label; // e.g. "1st (Section A)"
  const SchoolOrderClass({required this.value, required this.label});
}
