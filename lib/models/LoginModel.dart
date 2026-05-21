// To parse this JSON data, do
//
//     final loginModel = loginModelFromJson(jsonString);

import 'dart:convert';

LoginModel loginModelFromJson(String str) => LoginModel.fromJson(json.decode(str));

String loginModelToJson(LoginModel data) => json.encode(data.toJson());

class LoginModel {
  bool? status;
  String? message;
  User? user;
  String? token;
  bool? isProfileCompleted;

  LoginModel({
    this.status,
    this.message,
    this.user,
    this.token,
    this.isProfileCompleted,
  });

  LoginModel copyWith({
    bool? status,
    String? message,
    User? user,
    String? token,
    bool? isProfileCompleted,
  }) =>
      LoginModel(
        status: status ?? this.status,
        message: message ?? this.message,
        user: user ?? this.user,
        token: token ?? this.token,
        isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      );

  factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
    status: json["status"],
    message: json["message"],
    user: json["user"] == null ? null : User.fromJson(json["user"]),
    token: json["token"],
    isProfileCompleted: json["is_profile_completed"],
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "user": user?.toJson(),
    "token": token,
    "is_profile_completed": isProfileCompleted,
  };
}

class User {
  int? id;
  String? uuid;
  String? accountType;
  dynamic businessTypeId;
  dynamic countryId;
  dynamic stateId;
  dynamic cityId;
  String? name;
  dynamic lastName;
  dynamic username;
  dynamic email;
  dynamic referCode;
  dynamic address;
  dynamic pincode;
  dynamic emailVerifiedAt;
  dynamic emailVerifyToken;
  dynamic emailTokenValidTime;
  dynamic phone;
  dynamic lastChangeAt;
  dynamic lastPinChanged;
  dynamic lastLogin;
  dynamic phoneVerifiedAt;
  String? whatsappPhone;
  dynamic wphoneVerifiedAt;
  dynamic referedBy;
  dynamic gender;
  dynamic dob;
  dynamic googleId;
  dynamic facebookId;
  dynamic linkedinId;
  dynamic profilePic;
  int? walletBalance;
  int? referalBalance;
  dynamic password;
  dynamic forgetPasswordToken;
  dynamic forgetPasswordTokenExpire;
  dynamic passwordResetToken;
  dynamic passwordResetTokenExpire;
  dynamic status;
  dynamic g2FaSecret;
  dynamic g2FaVerifiedAt;
  dynamic g2FaEnabled;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  dynamic otp;
  DateTime? otpExpire;
  List<String>? wantAutomate;
  dynamic liveLocation;
  String? registeredTimeHuman;
  String? profilePhotoUrl;
  String? designation;
  String? sig;
  Map<String, dynamic>? school;
  int? schoolId;
  List<AssignedClass>? assignedClasses;

  User({
    this.id,
    this.uuid,
    this.accountType,
    this.businessTypeId,
    this.countryId,
    this.stateId,
    this.cityId,
    this.name,
    this.lastName,
    this.username,
    this.email,
    this.referCode,
    this.address,
    this.pincode,
    this.emailVerifiedAt,
    this.emailVerifyToken,
    this.emailTokenValidTime,
    this.phone,
    this.phoneVerifiedAt,
    this.whatsappPhone,
    this.wphoneVerifiedAt,
    this.referedBy,
    this.gender,
    this.dob,
    this.googleId,
    this.facebookId,
    this.linkedinId,
    this.profilePic,
    this.walletBalance,
    this.referalBalance,
    this.password,
    this.lastChangeAt,
    this.lastPinChanged,
    this.lastLogin,
    this.forgetPasswordToken,
    this.forgetPasswordTokenExpire,
    this.passwordResetToken,
    this.passwordResetTokenExpire,
    this.status,
    this.g2FaSecret,
    this.g2FaVerifiedAt,
    this.g2FaEnabled,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.otp,
    this.otpExpire,
    this.wantAutomate,
    this.liveLocation,
    this.registeredTimeHuman,
    this.profilePhotoUrl,
    this.designation,
    this.sig,
    this.school,
    this.schoolId,
    this.assignedClasses,
  });

  User copyWith({
    int? id,
    String? uuid,
    dynamic businessTypeId,
    dynamic countryId,
    dynamic stateId,
    dynamic cityId,
    String? name,
    dynamic lastName,
    dynamic username,
    dynamic email,
    dynamic referCode,
    dynamic address,
    dynamic pincode,
    dynamic emailVerifiedAt,
    dynamic emailVerifyToken,
    dynamic emailTokenValidTime,
    dynamic phone,
    dynamic phoneVerifiedAt,
    String? whatsappPhone,
    dynamic wphoneVerifiedAt,
    dynamic referedBy,
    dynamic gender,
    dynamic dob,
    dynamic googleId,
    dynamic facebookId,
    dynamic linkedinId,
    dynamic profilePic,
    int? walletBalance,
    int? referalBalance,
    dynamic password,
    dynamic lastChangeAt,
    dynamic lastPinChanged,
    dynamic lastLogin,
    dynamic forgetPasswordToken,
    dynamic forgetPasswordTokenExpire,
    dynamic passwordResetToken,
    dynamic passwordResetTokenExpire,
    int? status,
    dynamic g2FaSecret,
    dynamic g2FaVerifiedAt,
    int? g2FaEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    dynamic deletedAt,
    int? otp,
    DateTime? otpExpire,
    List<String>? wantAutomate,
    dynamic liveLocation,
    String? registeredTimeHuman,
    String? profilePhotoUrl,
  }) =>
      User(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        businessTypeId: businessTypeId ?? this.businessTypeId,
        countryId: countryId ?? this.countryId,
        stateId: stateId ?? this.stateId,
        cityId: cityId ?? this.cityId,
        name: name ?? this.name,
        lastName: lastName ?? this.lastName,
        username: username ?? this.username,
        email: email ?? this.email,
        referCode: referCode ?? this.referCode,
        address: address ?? this.address,
        pincode: pincode ?? this.pincode,
        emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
        emailVerifyToken: emailVerifyToken ?? this.emailVerifyToken,
        emailTokenValidTime: emailTokenValidTime ?? this.emailTokenValidTime,
        phone: phone ?? this.phone,
        phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
        whatsappPhone: whatsappPhone ?? this.whatsappPhone,
        wphoneVerifiedAt: wphoneVerifiedAt ?? this.wphoneVerifiedAt,
        referedBy: referedBy ?? this.referedBy,
        gender: gender ?? this.gender,
        dob: dob ?? this.dob,
        googleId: googleId ?? this.googleId,
        facebookId: facebookId ?? this.facebookId,
        linkedinId: linkedinId ?? this.linkedinId,
        profilePic: profilePic ?? this.profilePic,
        walletBalance: walletBalance ?? this.walletBalance,
        referalBalance: referalBalance ?? this.referalBalance,
        password: password ?? this.password,
        lastChangeAt: lastChangeAt ?? this.lastChangeAt,
        lastPinChanged: lastPinChanged ?? this.lastPinChanged,
        lastLogin: lastLogin ?? this.lastLogin,
        forgetPasswordToken: forgetPasswordToken ?? this.forgetPasswordToken,
        forgetPasswordTokenExpire: forgetPasswordTokenExpire ?? this.forgetPasswordTokenExpire,
        passwordResetToken: passwordResetToken ?? this.passwordResetToken,
        passwordResetTokenExpire: passwordResetTokenExpire ?? this.passwordResetTokenExpire,
        status: status ?? this.status,
        g2FaSecret: g2FaSecret ?? this.g2FaSecret,
        g2FaVerifiedAt: g2FaVerifiedAt ?? this.g2FaVerifiedAt,
        g2FaEnabled: g2FaEnabled ?? this.g2FaEnabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        otp: otp ?? this.otp,
        otpExpire: otpExpire ?? this.otpExpire,
        wantAutomate: wantAutomate ?? this.wantAutomate,
        liveLocation: liveLocation ?? this.liveLocation,
        registeredTimeHuman: registeredTimeHuman ?? this.registeredTimeHuman,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    uuid: json["uuid"],
    accountType: json["account_type"],
    businessTypeId: json["business_type_id"],
    countryId: json["country_id"],
    stateId: json["state_id"],
    cityId: json["city_id"],
    name: json["name"],
    lastName: json["last_name"],
    username: json["username"],
    email: json["email"],
    referCode: json["refer_code"],
    address: json["address"],
    pincode: json["pincode"],
    emailVerifiedAt: json["email_verified_at"],
    emailVerifyToken: json["email_verify_token"],
    emailTokenValidTime: json["email_token_valid_time"],
    phone: json["phone"],
    phoneVerifiedAt: json["phone_verified_at"],
    whatsappPhone: json["whatsapp_phone"],
    wphoneVerifiedAt: json["wphone_verified_at"],
    referedBy: json["refered_by"],
    gender: json["gender"],
    dob: json["dob"],
    googleId: json["google_id"],
    facebookId: json["facebook_id"],
    linkedinId: json["linkedin_id"],
    profilePic: json["profile_pic"],
    walletBalance: json["wallet_balance"],
    referalBalance: json["referal_balance"],
    password: json["password"],
    lastChangeAt: json["last_change_at"],
    lastPinChanged: json["last_pin_changed"],
    lastLogin: json["last_login"],
    forgetPasswordToken: json["forget_password_token"],
    forgetPasswordTokenExpire: json["forget_password_token_expire"],
    passwordResetToken: json["password_reset_token"],
    passwordResetTokenExpire: json["password_reset_token_expire"],
    status: json["status"],
    g2FaSecret: json["g2fa_secret"],
    g2FaVerifiedAt: json["g2fa_verified_at"],
    g2FaEnabled: json["g2fa_enabled"],
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    otp: json["otp"],
    otpExpire: json["otp_expire"] == null ? null : DateTime.parse(json["otp_expire"]),
    wantAutomate: json["want_automate"] == null ? [] : List<String>.from(json["want_automate"]!.map((x) => x)),
    liveLocation: json["live_location"],
    registeredTimeHuman: json["registered_time_human"],
    profilePhotoUrl: json["profile_photo_url"],
    designation: json["designation"],
    sig: json["sig"],
    school: json["school"] == null ? null : Map<String, dynamic>.from(json["school"]),
    schoolId: json["school_id"],
    assignedClasses: json["assigned_classes"] == null
        ? []
        : List<AssignedClass>.from(
            (json["assigned_classes"] as List).map((x) => AssignedClass.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "business_type_id": businessTypeId,
    "country_id": countryId,
    "state_id": stateId,
    "city_id": cityId,
    "name": name,
    "last_name": lastName,
    "username": username,
    "email": email,
    "refer_code": referCode,
    "address": address,
    "pincode": pincode,
    "email_verified_at": emailVerifiedAt,
    "email_verify_token": emailVerifyToken,
    "email_token_valid_time": emailTokenValidTime,
    "phone": phone,
    "phone_verified_at": phoneVerifiedAt,
    "whatsapp_phone": whatsappPhone,
    "wphone_verified_at": wphoneVerifiedAt,
    "refered_by": referedBy,
    "gender": gender,
    "dob": dob,
    "google_id": googleId,
    "facebook_id": facebookId,
    "linkedin_id": linkedinId,
    "profile_pic": profilePic,
    "wallet_balance": walletBalance,
    "referal_balance": referalBalance,
    "password": password,
    "forget_password_token": forgetPasswordToken,
    "forget_password_token_expire": forgetPasswordTokenExpire,
    "password_reset_token": passwordResetToken,
    "password_reset_token_expire": passwordResetTokenExpire,
    "status": status,
    "g2fa_secret": g2FaSecret,
    "g2fa_verified_at": g2FaVerifiedAt,
    "g2fa_enabled": g2FaEnabled,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "otp": otp,
    "otp_expire": otpExpire?.toIso8601String(),
    "want_automate": wantAutomate == null ? [] : List<dynamic>.from(wantAutomate!.map((x) => x)),
    "live_location": liveLocation,
    "registered_time_human": registeredTimeHuman,
    "profile_photo_url": profilePhotoUrl,
  };
}

class AssignedClass {
  final int id;
  final String className;

  const AssignedClass({required this.id, required this.className});

  factory AssignedClass.fromJson(Map<String, dynamic> json) {
    // Handle nested "class" object (from assigned-classes API response)
    final classObj = json["class"] as Map<String, dynamic>?;
    
    // Handle both "id"/"school_class_id" for the class ID
    final classId = classObj?["id"] 
        ?? json["school_class_id"] 
        ?? json["id"] 
        ?? 0;
    
    // Handle both "name"/"class_name" for the class name
    final name = classObj?["name"] 
        ?? classObj?["name_withprefix"]
        ?? json["class_name"] 
        ?? json["name"] 
        ?? '';
    
    return AssignedClass(
      id: classId is int ? classId : int.tryParse(classId.toString()) ?? 0,
      className: name.toString(),
    );
  }

  Map<String, dynamic> toJson() => {"id": id, "class_name": className};
}
