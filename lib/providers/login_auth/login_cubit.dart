

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/models/LoginModel.dart';
import 'package:idmitra/models/LogoutModel.dart';


part 'login_state.dart';
class LoginCubit extends Cubit<LoginState> {

  LoginCubit () : super (LoginInitial());

  ApiManager apiManager = ApiManager();

  constVerifyOtp(Map map) async {
    emit(OTPVerifyLoading());
    try {
      var response = await apiManager.postRequest(
          map, Config.baseUrl + Routes.otpVerify);
      debugPrint("response${response.body}");
      final jsonData = jsonDecode(response.body);  // FIXED HERE
      if (response.statusCode == 200) {

        LoginModel loginModel = LoginModel.fromJson(jsonData);
        print('Login user school: ${loginModel.user?.school}');
        print('Login user id: ${loginModel.user?.id}');
        print('Raw assigned_classes: ${jsonData['user']?['assigned_classes']}');
        print('Parsed assignedClasses: ${loginModel.user?.assignedClasses?.map((c) => c.toJson()).toList()}');

        // school data raw jsonData se extract karo
        final schoolData = (jsonData['user']?['school'] as Map<String, dynamic>?);
        print('Raw school data: $schoolData');

        // Save user locally
        await UserLocal.saveUser(loginModel.user);

        // Save school data locally
        if (schoolData != null) {
          await UserLocal.saveSchool(
            schoolId: schoolData['id']?.toString() ?? loginModel.user?.id?.toString() ?? '',
            schoolName: schoolData['name']?.toString() ?? '',
          );
        } else if (loginModel.user?.schoolId != null) {
          // Staff user — has school_id but no school object
          await UserLocal.saveSchool(
            schoolId: loginModel.user!.schoolId.toString(),
            schoolName: '',
          );
        } else {
          // super_admin without school — use user id as fallback
          await UserLocal.saveSchool(
            schoolId: loginModel.user?.id?.toString() ?? '',
            schoolName: loginModel.user?.name ?? '',
          );
        }

        // Save token securely
        // token field "token" ya "sig" mein se jo bhi available ho
        final token = jsonData["token"] ?? jsonData["user"]?["sig"];
        print('Token from response: $token');
        if (token != null) {
          await UserSecureStorage.setToken(token);
        } else {
          print('WARNING: No token found in login response!');
        }
        await UserSecureStorage.setRole(jsonData["user_type"] ?? loginModel.user?.accountType);
        emit(LoginSuccess(loginModel: loginModel, loginWithType: '', schoolData: schoolData));
      } else if (response.statusCode == 403 || response.statusCode == 400 || response.statusCode == 401) {
        final message = jsonData['message'] ?? "User not found";
        emit(OtpVerifyOnHold(message: message));
      } else {
        emit(LoginFailed());
      }
    } on SocketException {
      emit(LoginInternetError());
    } on TimeoutException {
      emit(LoginTimeout());
    } catch (e) {
      emit(LoginFailed());
    }
  }
  constSendOtp(Map map,String loginWithType) async {
    emit(LoginLoading());

    try {
      var response = await apiManager.postRequest(
        map,
        Config.baseUrl + Routes.sendOtp,
      );

      debugPrint("STATUS CODE => ${response.statusCode}");
      debugPrint("RESPONSE BODY => ${response.body}");

      if (response.body.isEmpty) {
        emit(LoginFailed());
        return;
      }

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        LoginModel loginModel = LoginModel.fromJson(jsonData);
        emit(LoginSuccess(loginModel: loginModel,loginWithType: loginWithType));
      } else if (response.statusCode == 403) {
        final message = jsonData['message'] ?? "User not found";
        emit(LoginOnHold(message: message));
      } else if (response.statusCode == 404) {
        final message = jsonData['message'] ?? "User not found";
        emit(LoginNoFound(message: message));
      } else {
        emit(LoginFailed());
      }
    } on SocketException {
      emit(LoginInternetError());
    } on TimeoutException {
      emit(LoginTimeout());
    } on FormatException {
      /// 🔥 JSON ERROR FIX
      debugPrint("Invalid JSON format");
      emit(LoginFailed());
    } catch (e) {
      debugPrint("ERROR => $e");
      emit(LoginFailed());
    }
  }

  constLogoutFun() async {
    emit(LoginLoading());
    try {
      var response = await apiManager.postRequest(
          {},
          Config.baseUrl + Routes.authLogout
      );

      debugPrint("response ${response.body}");
      final jsonData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 401) {
        // 401 means token already invalid - still logout locally
        LogoutModel logoutModel = LogoutModel(status: true, message: 'Logged out');
        emit(LogoutSuccess(logoutModel: logoutModel));
      } else if (response.statusCode == 403) {
        final message = jsonData['message'] ?? "User not found";
        emit(LoginOnHold(message: message));
      }
    } on SocketException {
      emit(LoginInternetError());
    } on TimeoutException {
      emit(LoginTimeout());
    } catch (e) {
      debugPrint("ERROR => $e");
      emit(LoginFailed());
    }
  }
  constGenratePassPinFun(Map map) async {
    emit(LoginLoading());
    try {
      var response = await apiManager.postRequest(
        map,
        Config.baseUrl + Routes.setCredentails,
      );

      debugPrint("response ${response.body}");
      final jsonData = jsonDecode(response.body);  // FIXED HERE
      if (response.statusCode == 200) {

        final message = jsonData['message'] ?? "User not found";
        final userType = jsonData['user_type'] ?? '';
        emit(PasswordSuccess(message: message, userType: userType));
      } else if (response.statusCode == 403) {
        final message = jsonData['message'] ?? "User not found";
        emit(LoginOnHold(message: message));
      }
    } on SocketException {
      emit(LoginInternetError());
    } on TimeoutException {
      emit(LoginTimeout());
    } catch (e) {
      debugPrint("ERROR => $e");
      emit(LoginFailed());
    }
  }
  constForgetPasswordVerifyOtp(Map map) async {
    emit(LoginLoading());
    try {
      var response = await apiManager.postRequest(
          map, Config.baseUrl + Routes.forgetPasswordVerifyOtp);
      debugPrint("response${response.body}");
      final jsonData = jsonDecode(response.body);  // FIXED HERE
      if (response.statusCode == 200) {
        final message = jsonData['message'] ?? "User not found";
        // Save token securely
        await UserSecureStorage.setToken(jsonData["token"]);
        emit(ForgetLoginSuccess(message: message));
      } else if (response.statusCode == 403 || response.statusCode == 400) {
        final message = jsonData['message'] ?? "User not found";
        emit(LoginOnHold(message: message));
      } else {
        emit(LoginFailed());
      }
    } on SocketException {
      emit(LoginInternetError());
    } on TimeoutException {
      emit(LoginTimeout());
    } catch (e) {
      emit(LoginFailed());
    }
  }
}