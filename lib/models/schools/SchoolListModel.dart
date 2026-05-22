// To parse this JSON data, do
//
//     final schoolListModel = schoolListModelFromJson(jsonString);

import 'dart:convert';

import 'package:idmitra/models/student_form/StudentFormFieldsModel.dart';

SchoolListModel schoolListModelFromJson(String str) => SchoolListModel.fromJson(json.decode(str));

String schoolListModelToJson(SchoolListModel data) => json.encode(data.toJson());

class SchoolListModel {
  bool? success;
  String? message;
  Data? data;

  SchoolListModel({
    this.success,
    this.message,
    this.data,
  });

  SchoolListModel copyWith({
    bool? success,
    String? message,
    Data? data,
  }) =>
      SchoolListModel(
        success: success ?? this.success,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory SchoolListModel.fromJson(Map<String, dynamic> json) => SchoolListModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
  };
}

class Data {
  Schools? schools;
  int? total;
  String? perPage;
  String? currentPage;
  int? lastPage;
  List<PermissionSchool>? permissionSchool;
  Filters? filters;

  Data({
    this.schools,
    this.total,
    this.perPage,
    this.currentPage,
    this.lastPage,
    this.permissionSchool,
    this.filters,
  });

  Data copyWith({
    Schools? schools,
    int? total,
    String? perPage,
    String? currentPage,
    int? lastPage,
    List<PermissionSchool>? permissionSchool,
    Filters? filters,
  }) =>
      Data(
        schools: schools ?? this.schools,
        total: total ?? this.total,
        perPage: perPage ?? this.perPage,
        currentPage: currentPage ?? this.currentPage,
        lastPage: lastPage ?? this.lastPage,
        permissionSchool: permissionSchool ?? this.permissionSchool,
        filters: filters ?? this.filters,
      );

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    schools: json["schools"] == null ? null : Schools.fromJson(json["schools"]),
    total: json["total"],
    perPage: json["per_page"]?.toString(),
    currentPage: json["current_page"]?.toString(),
    lastPage: json["last_page"],
    permissionSchool: json["permission_school"] == null ? [] : List<PermissionSchool>.from(json["permission_school"]!.map((x) => PermissionSchool.fromJson(x))),
    filters: json["filters"] == null ? null : Filters.fromJson(json["filters"]),
  );

  Map<String, dynamic> toJson() => {
    "schools": schools?.toJson(),
    "total": total,
    "per_page": perPage,
    "current_page": currentPage,
    "last_page": lastPage,
    "permission_school": permissionSchool == null ? [] : List<dynamic>.from(permissionSchool!.map((x) => x.toJson())),
    "filters": filters?.toJson(),
  };
}

class Filters {
  dynamic search;
  dynamic status;

  Filters({
    this.search,
    this.status,
  });

  Filters copyWith({
    dynamic search,
    dynamic status,
  }) =>
      Filters(
        search: search ?? this.search,
        status: status ?? this.status,
      );

  factory Filters.fromJson(Map<String, dynamic> json) => Filters(
    search: json["search"],
    status: json["status"],
  );

  Map<String, dynamic> toJson() => {
    "search": search,
    "status": status,
  };
}

class PermissionSchool {
  int? id;
  String? uuid;
  String? section;
  List<String>? actions;
  bool? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  Penal? penal;

  PermissionSchool({
    this.id,
    this.uuid,
    this.section,
    this.actions,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.penal,
  });

  PermissionSchool copyWith({
    int? id,
    String? uuid,
    String? section,
    List<String>? actions,
    bool? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic deletedAt,
    Penal? penal,
  }) =>
      PermissionSchool(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        section: section ?? this.section,
        actions: actions ?? this.actions,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        penal: penal ?? this.penal,
      );

  factory PermissionSchool.fromJson(Map<String, dynamic> json) => PermissionSchool(
    id: json["id"],
    uuid: json["uuid"],
    section: json["section"],
    actions: json["actions"] == null ? [] : List<String>.from(json["actions"]!.map((x) => x)),
    status: json["status"],
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    penal: penalValues.map[json["penal"]],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "section": section,
    "actions": actions == null ? [] : List<dynamic>.from(actions!.map((x) => x)),
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "penal": penalValues.reverse[penal],
  };
}

enum Penal {
  SCHOOL
}

final penalValues = EnumValues({
  "school": Penal.SCHOOL
});

class Schools {
  int? currentPage;
  List<SchoolDetailsModel>? data;
  String? firstPageUrl;
  int? from;
  int? lastPage;
  String? lastPageUrl;
  List<Link>? links;
  dynamic nextPageUrl;
  String? path;
  int? perPage;
  dynamic prevPageUrl;
  int? to;
  int? total;

  Schools({
    this.currentPage,
    this.data,
    this.firstPageUrl,
    this.from,
    this.lastPage,
    this.lastPageUrl,
    this.links,
    this.nextPageUrl,
    this.path,
    this.perPage,
    this.prevPageUrl,
    this.to,
    this.total,
  });

  Schools copyWith({
    int? currentPage,
    List<SchoolDetailsModel>? data,
    String? firstPageUrl,
    int? from,
    int? lastPage,
    String? lastPageUrl,
    List<Link>? links,
    dynamic nextPageUrl,
    String? path,
    int? perPage,
    dynamic prevPageUrl,
    int? to,
    int? total,
  }) =>
      Schools(
        currentPage: currentPage ?? this.currentPage,
        data: data ?? this.data,
        firstPageUrl: firstPageUrl ?? this.firstPageUrl,
        from: from ?? this.from,
        lastPage: lastPage ?? this.lastPage,
        lastPageUrl: lastPageUrl ?? this.lastPageUrl,
        links: links ?? this.links,
        nextPageUrl: nextPageUrl ?? this.nextPageUrl,
        path: path ?? this.path,
        perPage: perPage ?? this.perPage,
        prevPageUrl: prevPageUrl ?? this.prevPageUrl,
        to: to ?? this.to,
        total: total ?? this.total,
      );

  factory Schools.fromJson(Map<String, dynamic> json) => Schools(
    currentPage: json["current_page"],
    data: json["data"] == null ? [] : List<SchoolDetailsModel>.from(json["data"]!.map((x) => SchoolDetailsModel.fromJson(x))),
    firstPageUrl: json["first_page_url"],
    from: json["from"],
    lastPage: json["last_page"],
    lastPageUrl: json["last_page_url"],
    links: json["links"] == null ? [] : List<Link>.from(json["links"]!.map((x) => Link.fromJson(x))),
    nextPageUrl: json["next_page_url"],
    path: json["path"],
    perPage: json["per_page"],
    prevPageUrl: json["prev_page_url"],
    to: json["to"],
    total: json["total"],
  );

  Map<String, dynamic> toJson() => {
    "current_page": currentPage,
    "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "first_page_url": firstPageUrl,
    "from": from,
    "last_page": lastPage,
    "last_page_url": lastPageUrl,
    "links": links == null ? [] : List<dynamic>.from(links!.map((x) => x.toJson())),
    "next_page_url": nextPageUrl,
    "path": path,
    "per_page": perPage,
    "prev_page_url": prevPageUrl,
    "to": to,
    "total": total,
  };
}

class SchoolDetailsModel {
  int? id;
  String? uuid;
  int? schoolAdminId;
  int? partnerId;
  String? name;
  String? schoolPrefix;
  String? folderPrefix;
  dynamic countryId;
  dynamic stateId;
  dynamic cityId;
  String? address;
  String? pincode;
  String? logoPhoto;
  int? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  int? studentCount;
  int? staffCount;
  int? orderCount;
  String? logoUrl;
  dynamic currentSession;
  SchoolStorage? schoolStorage;
  SchoolStorage? schoolStorageCapturedByCamera;
  Partner? partner;
  Admin? admin;
  dynamic socialLinks;
  List<StudentFormField>? studentFormFields;
  List<StudentFormField>? availableStudentFormFields;
  String? sig; // signed URL param for student-form-fields web route
  String? imageShape; // image_shape from image settings (rectangle, square, round, oval)

  SchoolDetailsModel({
    this.id,
    this.uuid,
    this.schoolAdminId,
    this.partnerId,
    this.name,
    this.schoolPrefix,
    this.folderPrefix,
    this.countryId,
    this.stateId,
    this.cityId,
    this.address,
    this.pincode,
    this.logoPhoto,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.studentCount,
    this.staffCount,
    this.orderCount,
    this.logoUrl,
    this.currentSession,
    this.schoolStorage,
    this.schoolStorageCapturedByCamera,
    this.partner,
    this.admin,
    this.socialLinks,
    this.studentFormFields,
    this.availableStudentFormFields,
    this.sig,
    this.imageShape,
  });

  SchoolDetailsModel copyWith({
    int? id,
    String? uuid,
    int? schoolAdminId,
    int? partnerId,
    String? name,
    String? schoolPrefix,
    String? folderPrefix,
    dynamic countryId,
    dynamic stateId,
    dynamic cityId,
    String? address,
    String? pincode,
    String? logoPhoto,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic deletedAt,
    int? studentCount,
    int? staffCount,
    int? orderCount,
    String? logoUrl,
    dynamic currentSession,
    SchoolStorage? schoolStorage,
    SchoolStorage? schoolStorageCapturedByCamera,
    Partner? partner,
    Admin? admin,
    dynamic socialLinks,
    List<StudentFormField>? studentFormFields,
    List<StudentFormField>? availableStudentFormFields,
    String? sig,
    String? imageShape,
  }) =>
      SchoolDetailsModel(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        schoolAdminId: schoolAdminId ?? this.schoolAdminId,
        partnerId: partnerId ?? this.partnerId,
        name: name ?? this.name,
        schoolPrefix: schoolPrefix ?? this.schoolPrefix,
        folderPrefix: folderPrefix ?? this.folderPrefix,
        countryId: countryId ?? this.countryId,
        stateId: stateId ?? this.stateId,
        cityId: cityId ?? this.cityId,
        address: address ?? this.address,
        pincode: pincode ?? this.pincode,
        logoPhoto: logoPhoto ?? this.logoPhoto,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        studentCount: studentCount ?? this.studentCount,
        staffCount: staffCount ?? this.staffCount,
        orderCount: orderCount ?? this.orderCount,
        logoUrl: logoUrl ?? this.logoUrl,
        currentSession: currentSession ?? this.currentSession,
        schoolStorage: schoolStorage ?? this.schoolStorage,
        schoolStorageCapturedByCamera: schoolStorageCapturedByCamera ?? this.schoolStorageCapturedByCamera,
        partner: partner ?? this.partner,
        admin: admin ?? this.admin,
        socialLinks: socialLinks ?? this.socialLinks,
        studentFormFields: studentFormFields ?? this.studentFormFields,
        availableStudentFormFields: availableStudentFormFields ?? this.availableStudentFormFields,
        sig: sig ?? this.sig,
        imageShape: imageShape ?? this.imageShape,
      );

  factory SchoolDetailsModel.fromJson(Map<String, dynamic> json) => SchoolDetailsModel(
    id: json["id"],
    uuid: json["uuid"],
    schoolAdminId: json["school_admin_id"],
    partnerId: json["partner_id"],
    name: json["name"],
    schoolPrefix: json["school_prefix"],
    folderPrefix: json["folder_prefix"],
    countryId: json["country_id"],
    stateId: json["state_id"],
    cityId: json["city_id"],
    address: json["address"]?.toString(),
    pincode: json["pincode"]?.toString(),
    logoPhoto: json["logo_photo"]?.toString(),
    status: json["status"],
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    studentCount: json["student_count"],
    staffCount: json["staff_count"],
    orderCount: json["order_count"],
    logoUrl: json["logo_url"]?.toString(),
    currentSession: json["current_session"],
    schoolStorage: (json["school_storage"] is Map) ? SchoolStorage.fromJson(json["school_storage"]) : null,
    schoolStorageCapturedByCamera: (json["school_storage_captured_by_camera"] is Map) ? SchoolStorage.fromJson(json["school_storage_captured_by_camera"]) : null,
    partner: json["partner"] == null ? null : Partner.fromJson(json["partner"]),
    admin: json["admin"] == null ? null : Admin.fromJson(json["admin"]),
    socialLinks: json["social_links"],
    studentFormFields: json["student_form_fields"] == null
        ? []
        : List<StudentFormField>.from(
        json["student_form_fields"].map((x) => StudentFormField.fromJson(x))),
    availableStudentFormFields: json["available_student_form_fields"] == null
        ? []
        : List<StudentFormField>.from(
        json["available_student_form_fields"].map((x) => StudentFormField.fromJson(x))),
    sig: json["sig"],
    imageShape: json["image_shape"]?.toString(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "school_admin_id": schoolAdminId,
    "partner_id": partnerId,
    "name": name,
    "school_prefix": schoolPrefix,
    "folder_prefix": folderPrefix,
    "country_id": countryId,
    "state_id": stateId,
    "city_id": cityId,
    "address": address,
    "pincode": pincode,
    "logo_photo": logoPhoto,
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "logo_url": logoUrl,
    "current_session": currentSession,
    "school_storage": schoolStorage?.toJson(),
    "school_storage_captured_by_camera": schoolStorageCapturedByCamera?.toJson(),
    "partner": partner?.toJson(),
    "admin": admin?.toJson(),
    "social_links": socialLinks,
    "student_form_fields": studentFormFields == null
        ? []
        : List<dynamic>.from(studentFormFields!.map((x) => x.toJson())),
    "available_student_form_fields": availableStudentFormFields == null
        ? []
        : List<dynamic>.from(availableStudentFormFields!.map((x) => x.toJson())),
    "sig": sig,
    "image_shape": imageShape,
  };
}

class Admin {
  int? id;
  String? uuid;
  String? designation;
  String? name;
  String? email;
  String? phone;
  String? whatsappPhone;
  dynamic otp;
  dynamic otpExpire;
  dynamic fcmToken;
  int? emailVerified;
  dynamic emailVerificationToken;
  dynamic emailTokenValidTill;
  dynamic emailVerifiedAt;
  int? phoneVerified;
  dynamic phoneVerifiedAt;
  Map<String, List<String>>? permissions;
  int? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  String? profilePhotoUrl;

  Admin({
    this.id,
    this.uuid,
    this.designation,
    this.name,
    this.email,
    this.phone,
    this.whatsappPhone,
    this.otp,
    this.otpExpire,
    this.fcmToken,
    this.emailVerified,
    this.emailVerificationToken,
    this.emailTokenValidTill,
    this.emailVerifiedAt,
    this.phoneVerified,
    this.phoneVerifiedAt,
    this.permissions,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.profilePhotoUrl,
  });

  Admin copyWith({
    int? id,
    String? uuid,
    String? designation,
    String? name,
    String? email,
    String? phone,
    String? whatsappPhone,
    dynamic otp,
    dynamic otpExpire,
    dynamic fcmToken,
    int? emailVerified,
    dynamic emailVerificationToken,
    dynamic emailTokenValidTill,
    dynamic emailVerifiedAt,
    int? phoneVerified,
    dynamic phoneVerifiedAt,
    // Map<String, List<String>>? permissions,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic deletedAt,
    String? profilePhotoUrl,
  }) =>
      Admin(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        designation: designation ?? this.designation,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        whatsappPhone: whatsappPhone ?? this.whatsappPhone,
        otp: otp ?? this.otp,
        otpExpire: otpExpire ?? this.otpExpire,
        fcmToken: fcmToken ?? this.fcmToken,
        emailVerified: emailVerified ?? this.emailVerified,
        emailVerificationToken: emailVerificationToken ?? this.emailVerificationToken,
        emailTokenValidTill: emailTokenValidTill ?? this.emailTokenValidTill,
        emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
        phoneVerified: phoneVerified ?? this.phoneVerified,
        phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
        // permissions: permissions ?? this.permissions,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      );

  factory Admin.fromJson(Map<String, dynamic> json) => Admin(
    id: json["id"],
    uuid: json["uuid"],
    designation: json["designation"],
    name: json["name"],
    email: json["email"],
    phone: json["phone"],
    whatsappPhone: json["whatsapp_phone"],
    otp: json["otp"],
    otpExpire: json["otp_expire"],
    fcmToken: json["fcm_token"],
    emailVerified: json["email_verified"],
    emailVerificationToken: json["email_verification_token"],
    emailTokenValidTill: json["email_token_valid_till"],
    emailVerifiedAt: json["email_verified_at"],
    phoneVerified: json["phone_verified"],
    phoneVerifiedAt: json["phone_verified_at"],
    // permissions: Map.from(json["permissions"]!).map((k, v) => MapEntry<String, List<String>>(k, List<String>.from(v.map((x) => x)))),
    status: json["status"],
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    profilePhotoUrl: json["profile_photo_url"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "designation": designation,
    "name": name,
    "email": email,
    "phone": phone,
    "whatsapp_phone": whatsappPhone,
    "otp": otp,
    "otp_expire": otpExpire,
    "fcm_token": fcmToken,
    "email_verified": emailVerified,
    "email_verification_token": emailVerificationToken,
    "email_token_valid_till": emailTokenValidTill,
    "email_verified_at": emailVerifiedAt,
    "phone_verified": phoneVerified,
    "phone_verified_at": phoneVerifiedAt,
    // "permissions": Map.from(permissions!).map((k, v) => MapEntry<String, dynamic>(k, List<dynamic>.from(v.map((x) => x)))),
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "profile_photo_url": profilePhotoUrl,
  };
}

class Partner {
  int? id;
  int? creatorId;
  dynamic parentId;
  String? accountType;
  dynamic permissions;
  String? uuid;
  String? name;
  String? firmName;
  String? email;
  String? phone;
  String? whatsappPhone;
  String? password;
  dynamic otp;
  dynamic otpExpire;
  dynamic fcmToken;
  dynamic gstNumber;
  String? businessNature;
  int? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  String? profilePic;
  List<String>? type;
  List<String>? dealsIn;
  String? profilePhotoUrl;
  String? receivedAtFormatted;
  String? receivedAt;
  String? receivedAtHuman;

  Partner({
    this.id,
    this.creatorId,
    this.parentId,
    this.accountType,
    this.permissions,
    this.uuid,
    this.name,
    this.firmName,
    this.email,
    this.phone,
    this.whatsappPhone,
    this.password,
    this.otp,
    this.otpExpire,
    this.fcmToken,
    this.gstNumber,
    this.businessNature,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.profilePic,
    this.type,
    this.dealsIn,
    this.profilePhotoUrl,
    this.receivedAtFormatted,
    this.receivedAt,
    this.receivedAtHuman,
  });

  Partner copyWith({
    int? id,
    int? creatorId,
    dynamic parentId,
    String? accountType,
    dynamic permissions,
    String? uuid,
    String? name,
    String? firmName,
    String? email,
    String? phone,
    String? whatsappPhone,
    String? password,
    dynamic otp,
    dynamic otpExpire,
    dynamic fcmToken,
    dynamic gstNumber,
    String? businessNature,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic deletedAt,
    String? profilePic,
    List<String>? type,
    List<String>? dealsIn,
    String? profilePhotoUrl,
    String? receivedAtFormatted,
    String? receivedAt,
    String? receivedAtHuman,
  }) =>
      Partner(
        id: id ?? this.id,
        creatorId: creatorId ?? this.creatorId,
        parentId: parentId ?? this.parentId,
        accountType: accountType ?? this.accountType,
        permissions: permissions ?? this.permissions,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        firmName: firmName ?? this.firmName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        whatsappPhone: whatsappPhone ?? this.whatsappPhone,
        password: password ?? this.password,
        otp: otp ?? this.otp,
        otpExpire: otpExpire ?? this.otpExpire,
        fcmToken: fcmToken ?? this.fcmToken,
        gstNumber: gstNumber ?? this.gstNumber,
        businessNature: businessNature ?? this.businessNature,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        profilePic: profilePic ?? this.profilePic,
        type: type ?? this.type,
        dealsIn: dealsIn ?? this.dealsIn,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
        receivedAtFormatted: receivedAtFormatted ?? this.receivedAtFormatted,
        receivedAt: receivedAt ?? this.receivedAt,
        receivedAtHuman: receivedAtHuman ?? this.receivedAtHuman,
      );

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
    id: json["id"],
    creatorId: json["creator_id"],
    parentId: json["parent_id"],
    accountType: json["account_type"],
    permissions: json["permissions"],
    uuid: json["uuid"],
    name: json["name"],
    firmName: json["firm_name"],
    email: json["email"],
    phone: json["phone"],
    whatsappPhone: json["whatsapp_phone"],
    password: json["password"],
    otp: json["otp"],
    otpExpire: json["otp_expire"],
    fcmToken: json["fcm_token"],
    gstNumber: json["gst_number"],
    businessNature: json["business_nature"],
    status: json["status"],
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    profilePic: json["profile_pic"],
    // ✅ FIX: null-safe parsing for type and deals_in lists
    type: json["type"] == null
        ? []
        : List<String>.from(
        (json["type"] as List).map((x) => x?.toString() ?? '')),
    dealsIn: json["deals_in"] == null
        ? []
        : List<String>.from(
        (json["deals_in"] as List).map((x) => x?.toString() ?? '')),
    profilePhotoUrl: json["profile_photo_url"],
    receivedAtFormatted: json["received_at_formatted"]?.toString(),
    receivedAt: json["received_at"]?.toString(),
    receivedAtHuman: json["received_at_human"]?.toString(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "creator_id": creatorId,
    "parent_id": parentId,
    "account_type": accountType,
    "permissions": permissions,
    "uuid": uuid,
    "name": name,
    "firm_name": firmName,
    "email": email,
    "phone": phone,
    "whatsapp_phone": whatsappPhone,
    "password": password,
    "otp": otp,
    "otp_expire": otpExpire,
    "fcm_token": fcmToken,
    "gst_number": gstNumber,
    "business_nature": businessNature,
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "profile_pic": profilePic,
    "type": type == null ? [] : List<dynamic>.from(type!.map((x) => x)),
    "deals_in": dealsIn == null ? [] : List<dynamic>.from(dealsIn!.map((x) => x)),
    "profile_photo_url": profilePhotoUrl,
    "received_at_formatted": receivedAtFormatted,
    "received_at": receivedAt,
    "received_at_human": receivedAtHuman,
  };
}

class SchoolStorage {
  String? studentsPhoto;
  String? documents;
  String? parentPhoto;
  String? guardianPhoto;
  String? staffPhoto;

  SchoolStorage({
    this.studentsPhoto,
    this.documents,
    this.parentPhoto,
    this.guardianPhoto,
    this.staffPhoto,
  });

  SchoolStorage copyWith({
    String? studentsPhoto,
    String? documents,
    String? parentPhoto,
    String? guardianPhoto,
    String? staffPhoto,
  }) =>
      SchoolStorage(
        studentsPhoto: studentsPhoto ?? this.studentsPhoto,
        documents: documents ?? this.documents,
        parentPhoto: parentPhoto ?? this.parentPhoto,
        guardianPhoto: guardianPhoto ?? this.guardianPhoto,
        staffPhoto: staffPhoto ?? this.staffPhoto,
      );

  factory SchoolStorage.fromJson(Map<String, dynamic> json) => SchoolStorage(
    studentsPhoto: json["students_photo"]?.toString(),
    documents: json["documents"]?.toString(),
    parentPhoto: json["parent_photo"]?.toString(),
    guardianPhoto: json["guardian_photo"]?.toString(),
    staffPhoto: json["staff_photo"]?.toString(),
  );

  Map<String, dynamic> toJson() => {
    "students_photo": studentsPhoto,
    "documents": documents,
    "parent_photo": parentPhoto,
    "guardian_photo": guardianPhoto,
    "staff_photo": staffPhoto,
  };
}

class Link {
  String? url;
  String? label;
  int? page;
  bool? active;

  Link({
    this.url,
    this.label,
    this.page,
    this.active,
  });

  Link copyWith({
    String? url,
    String? label,
    int? page,
    bool? active,
  }) =>
      Link(
        url: url ?? this.url,
        label: label ?? this.label,
        page: page ?? this.page,
        active: active ?? this.active,
      );

  factory Link.fromJson(Map<String, dynamic> json) => Link(
    url: json["url"]?.toString(),
    label: json["label"]?.toString(),
    page: json["page"],
    active: json["active"],
  );

  Map<String, dynamic> toJson() => {
    "url": url,
    "label": label,
    "page": page,
    "active": active,
  };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}