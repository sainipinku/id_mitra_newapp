import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/local_db/global_summary_local_ds/global_summary_local_ds.dart';
import 'package:idmitra/models/global_summary/global_summary_model.dart';
import 'package:idmitra/providers/global_summary/global_summary_state.dart';

class GlobalSummaryCubit extends Cubit<GlobalSummaryState> {
  final _api = ApiManager();
  final _localDS = GlobalSummaryLocalDS();
  StreamSubscription? _connectivitySub;

  GlobalSummaryCubit() : super(const GlobalSummaryState()) {
    _init();
  }

  Future<void> _init() async {
    // Load any cached data immediately so UI shows something
    final cached = await _localDS.loadCachedSummary();
    if (cached != null) {
      emit(state.copyWith(
        localData: cached,
        status: GlobalSyncStatus.idle,
        statusText: 'Last synced: ${_formatDate(cached.syncedAt)}',
        progress: 1.0,
      ));
    }

    // Auto-sync when internet comes back
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (hasInternet && state.status != GlobalSyncStatus.syncing) {
        await syncFromServer();
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }

  // ─── Public: called by Sync button ───────────────────────────────────────

  Future<void> syncFromServer() async {
    if (state.isSyncing) return;

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      // Load from local if available
      final cached = await _localDS.loadCachedSummary();
      emit(state.copyWith(
        status: GlobalSyncStatus.noInternet,
        localData: cached,
        progress: cached != null ? 1.0 : 0.0,
        statusText: cached != null
            ? 'Offline — showing data from ${_formatDate(cached.syncedAt)}'
            : 'No internet connection',
      ));
      return;
    }

    emit(state.copyWith(
      status: GlobalSyncStatus.syncing,
      progress: 0.1,
      statusText: 'Connecting to server...',
    ));

    try {
      final url = Config.url(Routes.getGlobalSummary());
      final response = await _api.getRequest(url);

      if (response == null) {
        _emitError('Server unreachable. Please try again.');
        return;
      }

      emit(state.copyWith(progress: 0.4, statusText: 'Parsing data...'));

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (response.statusCode != 200 || json['success'] != true) {
        _emitError(json['message'] ?? 'Failed to fetch summary.');
        return;
      }

      final model = GlobalSummaryModel.fromJson(json);

      emit(state.copyWith(progress: 0.7, statusText: 'Saving to local database...'));

      await _localDS.saveSummary(model);

      emit(state.copyWith(progress: 0.9, statusText: 'Loading saved data...'));

      final cached = await _localDS.loadCachedSummary();

      emit(state.copyWith(
        status: GlobalSyncStatus.success,
        localData: cached,
        progress: 1.0,
        statusText: 'Synced successfully at ${_formatDate(DateTime.now())}',
        errorMessage: null,
      ));
    } catch (e) {
      _emitError('Unexpected error: $e');
    }
  }

  // ─── Load from local only (offline) ──────────────────────────────────────

  Future<void> loadFromLocal() async {
    final cached = await _localDS.loadCachedSummary();
    if (cached != null) {
      emit(state.copyWith(
        localData: cached,
        status: GlobalSyncStatus.idle,
        progress: 1.0,
        statusText: 'Last synced: ${_formatDate(cached.syncedAt)}',
      ));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _emitError(String msg) {
    emit(state.copyWith(
      status: GlobalSyncStatus.error,
      errorMessage: msg,
      statusText: msg,
      progress: 0.0,
    ));
  }

  Future<bool> _hasInternet() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none) && connectivity.length == 1) {
        return false;
      }
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}
