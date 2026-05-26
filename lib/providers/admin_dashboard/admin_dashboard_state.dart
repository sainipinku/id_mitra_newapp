part of 'admin_dashboard_cubit.dart';

class AdminDashboardState {
  final bool loading;
  final SchoolDashboardModel? dashboard;
  final String? error;
  final bool isOffline;

  AdminDashboardState({
    this.loading = false,
    this.dashboard,
    this.error,
    this.isOffline = false,
  });

  AdminDashboardState copyWith({
    bool? loading,
    SchoolDashboardModel? dashboard,
    String? error,
    bool? isOffline,
  }) =>
      AdminDashboardState(
        loading: loading ?? this.loading,
        dashboard: dashboard ?? this.dashboard,
        error: error,
        isOffline: isOffline ?? this.isOffline,
      );
}
