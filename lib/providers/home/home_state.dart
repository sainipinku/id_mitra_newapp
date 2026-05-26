part of 'home_cubit.dart';

class HomeState {
  final bool loading;
  final PartnerDashboardModel? dashboard;
  final UserDetailsModel? user;
  final String? error;
  final bool isOffline;

  HomeState({
    this.loading = false,
    this.dashboard,
    this.user,
    this.error,
    this.isOffline = false,
  });

  HomeState copyWith({
    bool? loading,
    PartnerDashboardModel? dashboard,
    UserDetailsModel? user,
    String? error,
    bool? isOffline,
  }) {
    return HomeState(
      loading: loading ?? this.loading,
      dashboard: dashboard ?? this.dashboard,
      user: user ?? this.user,
      error: error ?? this.error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
