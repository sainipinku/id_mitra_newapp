
import 'dart:convert';
import 'package:idmitra/models/LoginModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserLocal {
  static Future saveUser(User? user) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString("name", user!.name ?? "");
    prefs.setString("email", user.email ?? "");
    prefs.setString("phone", user.phone.toString());
    prefs.setString("gender", user.gender ?? "");
    prefs.setString("profileImage", user.profilePhotoUrl ?? "");
    prefs.setString("userId", user.id.toString() ?? "");
    prefs.setString("userUuid", user.uuid ?? "");
    prefs.setString("designation", user.designation ?? "");
    if (user.schoolId != null) {
      prefs.setString("schoolId", user.schoolId.toString());
    }
    // Save assigned_classes as JSON string
    if (user.assignedClasses != null) {
      print('Saving assignedClasses: ${user.assignedClasses!.map((c) => c.toJson()).toList()}');
      final encoded = jsonEncode(user.assignedClasses!.map((c) => c.toJson()).toList());
      prefs.setString("assignedClasses", encoded);
    }
  }

  static Future saveSchool({required String schoolId, required String schoolName}) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("schoolId", schoolId);
    prefs.setString("schoolName", schoolName);
  }

  static Future<Map<String, String?>> getSchool() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "schoolId": prefs.getString("schoolId"),
      "schoolName": prefs.getString("schoolName"),
    };
  }

  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      "name": prefs.getString("name"),
      "email": prefs.getString("email"),
      "phone": prefs.getString("phone"),
      "role": prefs.getString("role"),
      "gender": prefs.getString("gender"),
      "profileImage": prefs.getString("profileImage"),
      "userId": prefs.getString("userId"),
      "userUuid": prefs.getString("userUuid"),
      "designation": prefs.getString("designation"),
    };
  }

  static Future<List<AssignedClass>> getAssignedClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("assignedClasses");
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => AssignedClass.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future saveAssignedClasses(List<AssignedClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(classes.map((c) => c.toJson()).toList());
    await prefs.setString("assignedClasses", encoded);
  }

  static Future clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
