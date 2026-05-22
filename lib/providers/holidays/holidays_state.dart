import 'package:idmitra/models/holidays/HolidayModel.dart';

class HolidaysState {
  final bool loading;
  final List<HolidayModel> holidays;
  final String? error;
  final int total;
  final bool actionLoading;
  final String? actionError;

  const HolidaysState({
    this.loading = false,
    this.holidays = const [],
    this.error,
    this.total = 0,
    this.actionLoading = false,
    this.actionError,
  });

  HolidaysState copyWith({
    bool? loading,
    List<HolidayModel>? holidays,
    String? error,
    bool clearError = false,
    int? total,
    bool? actionLoading,
    String? actionError,
    bool clearActionError = false,
  }) {
    return HolidaysState(
      loading: loading ?? this.loading,
      holidays: holidays ?? this.holidays,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
      actionLoading: actionLoading ?? this.actionLoading,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}
