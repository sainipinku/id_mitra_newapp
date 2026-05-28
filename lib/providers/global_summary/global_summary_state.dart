import 'package:idmitra/local_db/global_summary_local_ds/global_summary_local_ds.dart';
import 'package:idmitra/models/global_summary/global_summary_model.dart';

enum GlobalSyncStatus { idle, syncing, success, error, noInternet }

class GlobalSummaryState {
  final GlobalSyncStatus status;
  final String? errorMessage;
  final GlobalSummaryLocalData? localData;
  final double progress; // 0.0 – 1.0 for progress bar
  final String statusText;

  const GlobalSummaryState({
    this.status = GlobalSyncStatus.idle,
    this.errorMessage,
    this.localData,
    this.progress = 0.0,
    this.statusText = "Tap 'Sync Backup' to download all data",
  });

  bool get isSyncing => status == GlobalSyncStatus.syncing;
  bool get hasData => localData != null;

  GlobalSummaryState copyWith({
    GlobalSyncStatus? status,
    String? errorMessage,
    GlobalSummaryLocalData? localData,
    double? progress,
    String? statusText,
  }) =>
      GlobalSummaryState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        localData: localData ?? this.localData,
        progress: progress ?? this.progress,
        statusText: statusText ?? this.statusText,
      );
}
