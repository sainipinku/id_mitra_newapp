import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:idmitra/api_mamanger/ApiResult.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/services/maintenance_service.dart';


class ApiManager {
  /// Checks the response status and triggers maintenance screen if server is down.
  /// Returns true if the response is a maintenance/server-error status.
  bool _handleMaintenanceCheck(int statusCode) {
    if (statusCode == 503 || statusCode == 502) {
      MaintenanceService.instance.onServerDown();
      return true;
    }
    // Server responded normally — dismiss maintenance if it was showing
    MaintenanceService.instance.onServerUp();
    return false;
  }

  getRequest(String url) async {
    try {
      var token = await UserSecureStorage.fetchToken();

      var response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
      );
      print('status code-----${response.statusCode} and base url----${url} and token-------$token');
      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 404 ||
          response.statusCode == 203 ||
          response.statusCode == 405 ||
          response.statusCode == 400) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('getRequest SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('getRequest error: $e');
      return null;
    }
  }

  patchRequest(String url) async {
    try {
      var token = await UserSecureStorage.fetchToken();

      var response = await http.patch(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          'Content-type': 'application/json',
          'Accept': 'application/json',
        },
      );
      print('status code-----${response.statusCode} and base url----${url}');
      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 203 ||
          response.statusCode == 400) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('patchRequest SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('patchRequest error: $e');
      return null;
    }
  }

  patchRequestWithBody(String url, Map<String, dynamic> body) async {
    try {
      var token = await UserSecureStorage.fetchToken();

      var response = await http.patch(
        Uri.parse(url),
        body: jsonEncode(body),
        headers: {
          "Authorization": "Bearer $token",
          'Content-type': 'application/json',
          'Accept': 'application/json',
        },
      );
      print('status code-----${response.statusCode} and base url----${url}');
      print('response body-----${response.body}');
      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 422 ||
          response.statusCode == 404 ||
          response.statusCode == 203 ||
          response.statusCode == 400) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('patchRequestWithBody SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('patchRequestWithBody error: $e');
      return null;
    }
  }

  Future<ApiResult> deleteRequest(String url) async {
    try {
      var token = await UserSecureStorage.fetchToken();

      var response = await http.delete(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          'Content-type': 'application/json',
          'Accept': 'application/json',
        },
      );
      print("""
URL: $url
Status Code: ${response.statusCode}
Response: ${response.body}
""");
      var jsonResponse = json.decode(response.body);
      if (_handleMaintenanceCheck(response.statusCode)) {
        return ApiResult(status: false, statusCode: response.statusCode, message: "Server maintenance");
      }
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 203 ||
          response.statusCode == 400) {
        return ApiResult(
          status: true,
          statusCode: response.statusCode,
          data: jsonResponse,
          message: jsonResponse["message"] ?? "Success",
        );
      } else {
        return ApiResult(
          status: true,
          statusCode: response.statusCode,
          data: jsonResponse,
          message: jsonResponse["message"] ?? "Success",
        );
      }
    } on SocketException catch (e) {
      print('deleteRequest SocketException: No internet connection - $e');
      return ApiResult(status: false, statusCode: 0, message: "No internet connection");
    } catch (e) {
      print('deleteRequest error: $e');
      return ApiResult(status: false, statusCode: 0, message: e.toString());
    }
  }

  putRequestWithBody(String url, Map<String, dynamic> body) async {
    try {
      var token = await UserSecureStorage.fetchToken();

      var response = await http.put(
        Uri.parse(url),
        body: jsonEncode(body),
        headers: {
          "Authorization": "Bearer $token",
          'Content-type': 'application/json',
          'Accept': 'application/json',
        },
      );
      print('status code-----${response.statusCode} and base url----${url}');
      print('response body-----${response.body}');
      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 422 ||
          response.statusCode == 203 ||
          response.statusCode == 400) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('putRequestWithBody SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('putRequestWithBody error: $e');
      return null;
    }
  }

  putRequest(String url) async {
    try {
      var token = await UserSecureStorage.fetchToken();

      var response = await http.put(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          'Content-type': 'application/json',
          'Accept': 'application/json',
        },
      );
      print('status code-----${response.statusCode} and base url----${url}');
      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 203 ||
          response.statusCode == 400) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('putRequest SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('putRequest error: $e');
      return null;
    }
  }

  postRequest(var body, String url) async {
    try {
      var token = await UserSecureStorage.fetchToken();
      Response? response;

      if (token == null) {
        response = await http.post(
          Uri.parse(url.trim()),
          body: jsonEncode(body),
          headers: {
            'Content-type': 'application/json',
            'Accept': 'application/json',
          },
        );
      } else {
        response = await http.post(
          Uri.parse(url.trim()),
          body: jsonEncode(body),
          headers: {
            "Authorization": "Bearer $token",
            'Content-type': 'application/json',
            'Accept': 'application/json',
          },
        );
      }

      print(response.body);
      print(response.statusCode);

      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 201 ||
          response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 422 || response.statusCode == 500) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('postRequest SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('postRequest error: $e');
      return null;
    }
  }

  postWithoutRequest(String url) async {
    try {
      var token = await UserSecureStorage.fetchToken();
      http.Response? response;
      print('token------------$token');
      if (token == null) {
        response = await http.post(
          Uri.parse(url.trim()),
          headers: {
            'Content-type': 'application/json',
            'Accept': 'application/json',
          },
        );
      } else {
        response = await http.post(
          Uri.parse(url.trim()),
          headers: {
            "Authorization": "Bearer $token",
            'Content-type': 'application/json',
            'Accept': 'application/json',
          },
        );
      }

      print(response.body);
      print(response.statusCode);
      if (_handleMaintenanceCheck(response.statusCode)) return null;
      if (response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 201 ||
          response.statusCode == 400) {
        return response;
      } else {
        return null;
      }
    } on SocketException catch (e) {
      print('postWithoutRequest SocketException: No internet connection - $e');
      return null;
    } catch (e) {
      print('postWithoutRequest error: $e');
      return null;
    }
  }
  multiRequestRoute(image, String url) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));

    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', image),
      );
    }

    // request.fields['user_name'] = userName;
    request.fields['image_type'] = 'photo';

    final token = await UserSecureStorage.fetchToken();

    request.headers['Authorization'] = "Bearer $token";

    try {
      final response = await request.send();

      return http.Response.fromStream(response);
    } catch (error) {
      // Handle errors

      return http.Response('Error sending request', 500);
    }
  }



  leadsMultiRequestRoute(image, String url) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    print("iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii000000000");
    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('files[${0}]', image),
      );
    }
    print("iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii0000000001");
    // request.fields['user_name'] = userName;
    // request.fields['user_phone'] = mobileNumber;

    final token = await UserSecureStorage.fetchToken();
    print("iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii0000000002");

    /// Headers
    request.headers.addAll({
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });
    print("iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii0000000004");
    try {
      final response = await request.send();
      print("iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii0000000005");
      return http.Response.fromStream(response);
    } catch (error) {
      // Handle errors

      return http.Response('Error sending request', 500);
    }
  }

  // update achievements
  Future<ApiResult> multipartApiCall({
    required String url,
    required Map<String, String> fields,
    required File? images,
  }) async {
    try {
      final uri = Uri.parse(url);
      final token = await UserSecureStorage.fetchToken();

      var request = http.MultipartRequest('POST', uri);

      /// Headers
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

      /// Fields Map
      fields.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      /// Images List
      /// Images List
      if (images != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_photo',
            images.path,
          ),
        );
      }

      /// Send Request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print("multipartApiCall URL: $url");
      print("multipartApiCall Status: ${response.statusCode}");
      print("multipartApiCall Response: $responseBody");

      var jsonResponse = json.decode(responseBody);

      /// SUCCESS
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult(
          status: true,
          statusCode: response.statusCode,
          data: jsonResponse,
          message: jsonResponse["message"] ?? "Success",
        );
      }
      /// ERROR
      else {
        String msg = jsonResponse["message"] ?? "Something went wrong";

        return ApiResult(
          status: false,
          statusCode: response.statusCode,
          message: jsonResponse["message"] ?? "Success",
        );
      }
    } catch (e) {
      // Helpers().showAnimatedToast(GlobalContext.navigatorKey.currentContext!, "Achievement Updated Successfully");

      return ApiResult(status: false, statusCode: 0, message: e.toString());
    }
  }

  Future<ApiResult> multipartSingleImageApiCall({
    required String url,
    required Map<String, String> fields,
    File? image,
    String imageKey = "firm_image",
  }) async {
    try {
      final uri = Uri.parse(url);
      final token = await UserSecureStorage.fetchToken();

      var request = http.MultipartRequest('POST', uri);

      /// Headers
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

      /// Fields
      fields.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      /// Single Image
      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(imageKey, image.path),
        );
      }

      /// Send Request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      /// SUCCESS
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult(
          status: true,
          statusCode: response.statusCode,
          data: jsonResponse,
          message: jsonResponse["message"] ?? "Success",
        );
      } else {
        return ApiResult(
          status: false,
          statusCode: response.statusCode,
          data: jsonResponse,
          message: jsonResponse["message"] ?? "Something went wrong",
        );
      }
    } catch (e) {
      return ApiResult(status: false, statusCode: 0, message: e.toString());
    }
  }

  registerComplainFormRequest(
      String categoryType,
      String type,
      String subject,
      String description,
      String blockId,
      String unitId,
      String priorityId,
      List<File> documentFiles,
      url,
      ) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));

    if (documentFiles.isNotEmpty) {
      for (var i = 0; i < documentFiles.length; i++) {
        request.files.add(
          await http.MultipartFile.fromBytes(
            'attch_file[]',
            await documentFiles[i].readAsBytes(),
            filename: documentFiles[i].path.split('/').last,
          ),
        );
      }
    }

    request.fields['category_type'] = categoryType;
    request.fields['type'] = type;
    request.fields['subject'] = subject;
    request.fields['description'] = description;
    request.fields['block_id'] = blockId;
    request.fields['unit_id'] = unitId;
    request.fields['priority_level'] = priorityId;

    final token = await UserSecureStorage.fetchToken();

    request.headers['Authorization'] = "Bearer $token";

    try {
      final response = await request.send();

      return http.Response.fromStream(response);
    } catch (error) {
      // Handle errors

      return http.Response('Error sending request', 500);
    }
  }

  uploadIncomingDocument(
      String documentId,
      List<File> documentFiles,
      url,
      ) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));

    if (documentFiles.isNotEmpty) {
      for (var i = 0; i < documentFiles.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'documents[]',
            await documentFiles[i].readAsBytes(),
            filename: documentFiles[i].path.split('/').last,
          ),
        );
      }
    }

    request.fields['documentId'] = documentId;

    final token = await UserSecureStorage.fetchToken();

    request.headers['Authorization'] = "Bearer $token";

    try {
      final response = await request.send();

      return http.Response.fromStream(response);
    } catch (error) {

      return http.Response('Error sending request', 500);
    }
  }
}
