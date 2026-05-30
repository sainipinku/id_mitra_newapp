class Config {
  static String proBaseUrl = "https://idmitra.com/api/";
  static String baseUrl = proBaseUrl;
  static String schoolBaseUrl = "https://idmitra.com/";

  /// Safely joins baseUrl + route, removing any accidental double slashes
  static String url(String route) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final path = route.startsWith('/') ? route.substring(1) : route;
    return '$base$path';
  }
}

class Routes {
  static String sendOtp = "auth/send-otp";
  static String forgetPasswordSendOtp = "auth/forgot-password/send-otp";
  static String forgetPasswordVerifyOtp = "auth/forgot-password/verify-otp";
  static String otpVerify = "auth/verify-otp";
  static String setCredentails = "auth/profile/set-credentials";
  static String commonStates = "common/states/1";
  static String commonCites(String stateID) => "common/cities/$stateID";
  static String userUploadProfilePhoto = "user/upload-profile-photo";
  static String authLogout = "auth/logout";
  static String leadsFatchData = "leads/fatch-data";
  static String addLeadsData = "leads";
  static String addEvents = "events";
  static String authProfileUpdate = "auth/profile/update";
  static String getPartnerDashboardData() => "auth/partner/dashboard?filter=5_year";
  static String getUserDetails() => "auth/user";
  static String getSchoolList(int pageNo) => "auth/partner/schools?page=$pageNo";
  static String updateStudentProfile(String studentID) => "auth/school/students/$studentID/image";
  static String deleteStudent(String schoolId, String studentID) => "auth/school/$schoolId/students/$studentID";
  static String updateStudent(String schoolId, String studentID) => "auth/school/$schoolId/students/$studentID";
  static String updateEventLeadsStatus(String eventId) => "events/$eventId/set-active-lead";
  static String getLeadsList(String name,String status) => "leads?search=$name&status=$status";
  static String getEventsList(String name,String status,int pageNo) => "events?search=$name&status=$status&page=$pageNo";
  static String getStudentFormFields(String schoolId) => "auth/partner/school/$schoolId/student-form-fields";
  static String getSchoolFormFields(String schoolId) => "auth/school/$schoolId/form-fields";
  static String getStaffFormFields(String schoolId, {bool isPartner = false}) =>
      "auth/school/$schoolId/form-fields/staff";
  static String getStaffRoles(String schoolId, {bool isPartner = false}) =>
      isPartner
          ? "auth/partner/school/$schoolId/staff/roles/list"
          : "auth/school/$schoolId/staff/roles/list";
  static String addStaff(String schoolId, {bool isPartner = false}) =>
      "auth/school/$schoolId/staff";
  static String getStaffList(String schoolId, {int page = 1, String search = '', bool isPartner = false}) {
    final base = "auth/school/$schoolId/staff?page=$page";
    return search.isNotEmpty ? "$base&search=$search" : base;
  }
  static String getStaffDetail(String schoolId, String uuid, {bool isPartner = false}) =>
      "auth/school/$schoolId/staff/$uuid";
  static String updateStaff(String schoolId, String uuid, {bool isPartner = false}) =>
      "auth/school/$schoolId/staff/$uuid";
  static String deleteStaff(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid";
  static String changeStaffPassword(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid/password";
  static String toggleStaffStatus(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid/status";
  static String staffAssignedClasses(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid/assigned-classes";
  static String staffAssignClass(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid/assign-class";
  static String staffRemoveAssignedClass(String schoolId, String assignedClassUuid) =>
      "auth/school/$schoolId/staff/assigned-classes/$assignedClassUuid";
  static String uploadStaffSignature(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid/signature";
  static String uploadStaffPhoto(String schoolId, String uuid) =>
      "auth/school/$schoolId/staff/$uuid/photo";
  static String updateSchoolStudentFormFields(String schoolId) => "auth/school/$schoolId/form-fields/student";
  static String updateLeadsStatus(String leadsId,String status) => "leads/$leadsId/change-status/$status";
  static String toggleStudentStatus(String schoolId, String studentId) => "auth/school/$schoolId/students/$studentId/status";
  static String getOrders({int page = 1, String? status, String? search}) {
    var url = "auth/partner/orders?page=$page";
    if (status != null && status.isNotEmpty) url += "&status=$status";
    if (search != null && search.isNotEmpty) url += "&search=$search";
    return url;
  }
  static String getOrderDetail(String uuid, {String schoolId = ''}) =>
      "auth/partner/orders/$uuid";

  static String bulkUpdateStaffOrderStatus(String schoolId) =>
      "auth/school/$schoolId/staff/orders/status";

  static String getStaffOrderDetail(String uuid, {required String schoolId}) =>
      "auth/partner/orders/$uuid";
  static String updateOrderStatus(String uuid, {String schoolId = ''}) =>
      schoolId.isNotEmpty ? "auth/school/$schoolId/orders/$uuid/status" : "auth/partner/orders/$uuid/status";
  static String getOrderStatistics() => "auth/partner/orders/statistics/summary";
  static String getSchoolDashboard() => "auth/school/dashboard/stats";
  static String getSubCategoryById(String stateID) => "common/cities/$stateID";
  static String getSubCategoryProductById(String subCatId) => "product/subcategory/$subCatId";
  static String updateImageSettings(String schoolId) => "auth/school/image-settings/$schoolId";
  static String getAppVersion() => "app/version";
  static String moveStudentToExtra(String schoolId, String studentUuid) =>
      "auth/school/$schoolId/students/$studentUuid/move-to-extra";
  static String assignStudent(String schoolId, String studentUuid) =>
      "auth/school/$schoolId/students/$studentUuid/assign";
  static String getClassStudents(String schoolId, String classId) =>
      "auth/school/$schoolId/classes/$classId/students";
  static String getHolidays(String schoolId, {int? year, String search = ''}) {
    String url = "auth/school/$schoolId/holidays?per_page=100";
    if (year != null) url += "&year=$year";
    if (search.isNotEmpty) url += "&search=$search";
    return url;
  }
  static String addHoliday(String schoolId) => "auth/school/$schoolId/holidays";
  static String deleteHoliday(String schoolId, int holidayId) => "auth/school/$schoolId/holidays/$holidayId";
  // Legacy endpoint (kept for reference)
  static String getAttendanceLegacy(String schoolId, int classId, String date) =>
      "auth/school/$schoolId/attendance/get?class_id=$classId&date=$date";

  // New unified attendance endpoint
  static String getAttendance(String schoolId, {int? classId, String? date}) {
    var url = "auth/school/$schoolId/attendance";
    final params = <String>[];
    if (classId != null) params.add('class_id=$classId');
    if (date != null && date.isNotEmpty) params.add('date=$date');
    if (params.isNotEmpty) url = '$url?${params.join('&')}';
    return url;
  }

  static String getGlobalSummary() => "auth/partner/global/summary";
  static String getGlobalData({
    String include = 'schools,students,orders,staff_orders,student_corrections,staff_corrections',
    int schoolsPerPage = 25,
    int studentsPerPage = 25,
    int ordersPerPage = 25,
  }) =>
      "auth/partner/global/data?include=$include&schools_per_page=$schoolsPerPage&students_per_page=$studentsPerPage&orders_per_page=$ordersPerPage";
}

