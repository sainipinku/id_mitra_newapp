import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/db_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/add_student/StudentFormDataModel.dart';

class StudentFormDataState {
  final bool loading;
  final StudentFormDataModel? data;
  final String? error;
  const StudentFormDataState({this.loading = false, this.data, this.error});
}

class StudentFormDataCubit extends Cubit<StudentFormDataState> {
  StudentFormDataCubit() : super(const StudentFormDataState());

  Future<void> load(String schoolId) async {
    emit(const StudentFormDataState(loading: true));

    final localData = await _loadFromLocal(schoolId);
    if (localData != null) {
      emit(StudentFormDataState(loading: false, data: localData));
      _syncFromApi(schoolId);
      return;
    }

    // No local data — check internet before hitting API
    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      // Offline with no cached data: emit empty model so form still renders
      emit(StudentFormDataState(
        loading: false,
        data: StudentFormDataModel(sessions: [], classes: [], houses: []),
      ));
      return;
    }

    await _syncFromApi(schoolId, emitStates: true);
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<StudentFormDataModel?> _loadFromLocal(String schoolId) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'school_form_data',
        where: 'school_id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final sessions = jsonDecode(row['sessions_json'] as String? ?? '[]') as List;
      final classes = jsonDecode(row['classes_json'] as String? ?? '[]') as List;
      final houses = jsonDecode(row['houses_json'] as String? ?? '[]') as List;

      print('[FormData] Loaded from local DB — classes: ${classes.length}, sessions: ${sessions.length}, houses: ${houses.length}');

      return StudentFormDataModel.fromJson({
        'sessions': sessions,
        'classes': classes,
        'houses': houses,
      });
    } catch (e) {
      print('[FormData] Local load error: $e');
      return null;
    }
  }

  Future<void> _syncFromApi(String schoolId, {bool emitStates = false}) async {
    try {
      final token = await UserSecureStorage.fetchToken();
      final url = '${Config.baseUrl}auth/school/$schoolId/students/form-data';
      print('[FormData] API URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('[FormData] API response received');
        final model = StudentFormDataModel.fromJson(decoded);
        print('[FormData] Classes: ${model.classes.length}');

        await _saveToLocal(schoolId, model);

        if (emitStates) {
          emit(StudentFormDataState(data: model));
        } else {
          emit(StudentFormDataState(data: model));
        }
      } else {
        if (emitStates) {
          emit(StudentFormDataState(error: 'Failed: ${response.statusCode}'));
        }
      }
    } catch (e) {
      print('[FormData] API sync error: $e');
      if (emitStates) {
        emit(StudentFormDataState(error: e.toString()));
      }
    }
  }

  Future<void> _saveToLocal(String schoolId, StudentFormDataModel model) async {
    try {
      final db = await DBHelper.db;

      // Convert to raw JSON for storage
      final data = model;
      final sessionsJson = jsonEncode(
        data.sessions.map((s) => {'value': s.value, 'label': s.label}).toList(),
      );
      final classesJson = jsonEncode(
        data.classes.map((c) => {
          'id': c.id,
          'name': c.name,
          'name_withprefix': c.nameWithPrefix,
          'sections': c.sections.map((s) => {'id': s.id, 'name': s.name}).toList(),
          'sections_ids': c.sectionsIds,
        }).toList(),
      );
      final housesJson = jsonEncode(
        data.houses.map((h) => {'id': h.id, 'name': h.name}).toList(),
      );

      await db.insert(
        'school_form_data',
        {
          'school_id': schoolId,
          'sessions_json': sessionsJson,
          'classes_json': classesJson,
          'houses_json': housesJson,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('[FormData] Saved to local DB — school: $schoolId');
    } catch (e) {
      print('[FormData] Local save error: $e');
    }
  }
}
