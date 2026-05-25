import 'dart:convert'; 
 
 import 'package:flutter_bloc/flutter_bloc.dart'; 
 import 'package:idmitra/api_mamanger/api_manager.dart'; 
 import 'package:idmitra/api_mamanger/config.dart'; 
 import 'package:idmitra/db_helper.dart'; 
 import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart'; 
 import 'package:idmitra/models/home/PartnerDashboardModel.dart'; 
 import 'package:idmitra/models/home/UserDetailsModel.dart'; 
 import 'package:sqflite/sqflite.dart'; 
 
 part 'home_state.dart'; 
 
 const _kDashboardKey = 'dashboard'; 
 const _kUserKey = 'user'; 
 
 class HomeCubit extends Cubit<HomeState> { 
   HomeCubit() : super(HomeState()); 
 
   ApiManager apiManager = ApiManager(); 
   final localDS = StudentLocalDS(); 
 
 
   Future<void> _saveToLocal(String key, Map<String, dynamic> json) async { 
     try { 
       final db = await DBHelper.db; 
       await db.insert( 
         'home_cache', 
         { 
           'key': key, 
           'json_data': jsonEncode(json), 
           'updated_at': DateTime.now().millisecondsSinceEpoch, 
         }, 
         conflictAlgorithm: ConflictAlgorithm.replace, 
       ); 
       print('HomeCubit saved to local DB: $key'); 
     } catch (e) { 
       print('HomeCubit local save error: $e'); 
     } 
   } 
 
   Future<Map<String, dynamic>?> _loadFromLocal(String key) async { 
     try { 
       final db = await DBHelper.db; 
       final rows = await db.query( 
         'home_cache', 
         where: 'key = ?', 
         whereArgs: [key], 
         limit: 1, 
       ); 
       if (rows.isEmpty) return null; 
       final data = jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>; 
       return data; 
     } catch (e) { 
       print('HomeCubit local load error: $e'); 
       return null; 
     } 
   } 
 
 

   Future<PartnerDashboardModel> _injectLocalStudentCount(PartnerDashboardModel model) async { 
     try { 
       final localCount = await localDS.getCount(); 
       if (localCount > 0 && model.data != null) { 
         final updatedStudents = Employees( 
           total: localCount, 
           active: model.data!.students?.active, 
           inactive: model.data!.students?.inactive, 
         ); 
         final updatedData = Data( 
           filters: model.data!.filters, 
           orders: model.data!.orders, 
           schools: model.data!.schools, 
           users: model.data!.users, 
           schoolAdmins: model.data!.schoolAdmins, 
           students: updatedStudents, 
           subPartners: model.data!.subPartners, 
           employees: model.data!.employees, 
           partner: model.data!.partner, 
           period: model.data!.period, 
           dateRange: model.data!.dateRange, 
           summary: model.data!.summary, 
         ); 
         print('HomeCubit: injected local student count = $localCount'); 
         return PartnerDashboardModel( 
           success: model.success, 
           message: model.message, 
           data: updatedData, 
         ); 
       } 
     } catch (e) { 
       print('HomeCubit: local student count error: $e'); 
     } 
     return model; 
   } 
 
 
   Future<void> loadHomeData() async { 
     emit(state.copyWith(loading: true)); 
 
     final localDashboard = await _loadFromLocal(_kDashboardKey); 
     final localUser = await _loadFromLocal(_kUserKey); 
 
     if (localDashboard != null && localUser != null) { 
       var dashboardModel = PartnerDashboardModel.fromJson(localDashboard); 
       final userModel = UserDetailsModel.fromJson(localUser); 

       dashboardModel = await _injectLocalStudentCount(dashboardModel); 

       print('Full Local Dashboard Data: dashboard=${dashboardModel.data?.schools?.total} schools, students=${dashboardModel.data?.students?.total}'); 
       print('Full Local User Data: user=${userModel.user?.name}'); 
 
       emit(state.copyWith( 
         loading: false, 
         dashboard: dashboardModel, 
         user: userModel, 
       )); 
 
       _syncFromApi(); 
       return; 
     } 
 
     await _syncFromApi(emitStates: true); 
   } 
 
 
   Future<void> _syncFromApi({bool emitStates = false}) async { 
     try { 
       final dashboardResponse = await apiManager.getRequest( 
         Config.baseUrl + Routes.getPartnerDashboardData(), 
       ); 
       final userResponse = await apiManager.getRequest( 
         Config.baseUrl + Routes.getUserDetails(), 
       ); 
 
       if (dashboardResponse == null || userResponse == null) { 
         print('HomeCubit sync: no response (offline)'); 
         if (emitStates) emit(state.copyWith(loading: false)); 
         return; 
       } 
 
       print('HomeCubit sync dashboard status: ${dashboardResponse.statusCode}'); 
       print('HomeCubit sync dashboard body: ${dashboardResponse.body}'); 
       print('HomeCubit sync user status: ${userResponse.statusCode}'); 
       print('HomeCubit sync user body: ${userResponse.body}'); 
 
       if (dashboardResponse.statusCode == 403 || userResponse.statusCode == 403) { 
         if (emitStates) emit(state.copyWith(loading: false, error: 'On Hold')); 
         return; 
       } 
 
       if (dashboardResponse.statusCode == 200 && userResponse.statusCode == 200) { 
         final dashboardBody = dashboardResponse.body.trim(); 
         final userBody = userResponse.body.trim(); 
 
         if (dashboardBody.startsWith('<') || userBody.startsWith('<')) { 
           if (emitStates) emit(state.copyWith(loading: false)); 
           return; 
         } 
 
         final dashboardJson = jsonDecode(dashboardBody) as Map<String, dynamic>; 
         final userJson = jsonDecode(userBody) as Map<String, dynamic>; 
 
         final dashboardModel = PartnerDashboardModel.fromJson(dashboardJson); 
         final userModel = UserDetailsModel.fromJson(userJson); 
 
         await _saveToLocal(_kDashboardKey, dashboardJson); 
         await _saveToLocal(_kUserKey, userJson); 
 
         final updatedDashboard = await _injectLocalStudentCount(dashboardModel); 
 
         print('HomeCubit synced — schools: ${updatedDashboard.data?.schools?.total}, students: ${updatedDashboard.data?.students?.total}, user: ${userModel.user?.name}'); 
 
         emit(state.copyWith( 
           loading: false, 
           dashboard: updatedDashboard, 
           user: userModel, 
         )); 
       } else { 
         if (emitStates) emit(state.copyWith(loading: false)); 
       } 
     } catch (e) { 
       print('HomeCubit sync error: $e'); 
       if (emitStates) emit(state.copyWith(loading: false)); 
     } 
   } 
 } 
