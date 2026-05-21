// To parse this JSON data, do
//
//     final studentsListModel = studentsListModelFromJson(jsonString);

import 'dart:convert';

StudentsListModel studentsListModelFromJson(String str) => StudentsListModel.fromJson(json.decode(str));

String studentsListModelToJson(StudentsListModel data) => json.encode(data.toJson());

class StudentsListModel {
  bool? success;
  Data? data;
  Meta? meta;
  Filters? filters;

  StudentsListModel({
    this.success,
    this.data,
    this.meta,
    this.filters,
  });

  factory StudentsListModel.fromJson(Map<String, dynamic> json) => StudentsListModel(
    success: json["success"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
    meta: json["meta"] == null ? null : Meta.fromJson(json["meta"]),
    filters: json["filters"] == null ? null : Filters.fromJson(json["filters"]),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "data": data?.toJson(),
    "meta": meta?.toJson(),
    "filters": filters?.toJson(),
  };
}

class Data {
  int? currentPage;
  List<StudentDetailsData>? data;
  String? firstPageUrl;
  int? from;
  int? lastPage;
  String? lastPageUrl;
  List<Link>? links;
  String? nextPageUrl;
  String? path;
  int? perPage;
  dynamic prevPageUrl;
  int? to;
  int? total;

  Data({
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

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    currentPage: json["current_page"],
    data: json["data"] == null
        ? []
        : List<StudentDetailsData>.from(
        json["data"]!.map((x) => StudentDetailsData.fromJson(x))),
    firstPageUrl: json["first_page_url"],
    from: json["from"],
    lastPage: json["last_page"],
    lastPageUrl: json["last_page_url"],
    links: json["links"] == null
        ? []
        : List<Link>.from(json["links"]!.map((x) => Link.fromJson(x))),
    nextPageUrl: json["next_page_url"],
    path: json["path"],
    perPage: json["per_page"],
    prevPageUrl: json["prev_page_url"],
    to: json["to"],
    total: json["total"],
  );

  Map<String, dynamic> toJson() => {
    "current_page": currentPage,
    "data": data == null
        ? []
        : List<dynamic>.from(data!.map((x) => x.toJson())),
    "first_page_url": firstPageUrl,
    "from": from,
    "last_page": lastPage,
    "last_page_url": lastPageUrl,
    "links": links == null
        ? []
        : List<dynamic>.from(links!.map((x) => x.toJson())),
    "next_page_url": nextPageUrl,
    "path": path,
    "per_page": perPage,
    "prev_page_url": prevPageUrl,
    "to": to,
    "total": total,
  };
}

class StudentDetailsData {
  int? id;
  String? uuid;
  int? schoolId;
  dynamic uidNo;
  String? srNo;
  dynamic panNo;
  String? name;
  dynamic email;
  dynamic phone;
  dynamic whatsappPhone;
  dynamic landLineNo;
  dynamic photo;
  dynamic signature;
  dynamic barcodePhoto;
  String? dob;
  dynamic dobTimestamp;
  dynamic gender;
  dynamic bloodGroup;
  int? schoolClassId;
  dynamic schoolHouseId;
  int? schoolSessionId;
  int? schoolClassSectionId;
  dynamic transportMode;
  dynamic regNo;
  dynamic rollNo;
  dynamic aadharNo;
  dynamic admissionNo;
  dynamic rfidNo;
  dynamic countryId;
  dynamic stateId;
  dynamic cityId;
  String? address;
  dynamic pincode;
  String? loginId;
  int? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  String? fatherName;
  dynamic fatherEmail;
  String? fatherPhone;
  dynamic fatherWphone;
  dynamic fatherPhoto;
  dynamic fatherSignature;
  String? motherName;
  dynamic motherEmail;
  dynamic motherPhone;
  dynamic motherWphone;
  dynamic motherPhoto;
  dynamic motherSignature;
  dynamic relation;
  List<String>? missingFields;
  dynamic guardianName;
  dynamic guardianEmail;
  dynamic guardianPhone;
  dynamic guardianWhatsappPhone;
  dynamic guardianPhoto;
  dynamic guardianSignature;
  dynamic studentNicId;
  dynamic caste;
  dynamic isRteStudent;
  dynamic religion;
  String? profilePhotoUrl;
  String? pdfProfilePhotoUrl;
  dynamic signatureUrl;
  String? fatherPhotoUrl;
  dynamic fatherSignatureUrl;
  String? motherPhotoUrl;
  dynamic motherSignatureUrl;
  bool isOffline;
  bool isExtra;
  bool isOfflineUpdate;
  bool isExtraPendingSync;
  bool isDeletePendingSync;
  bool isStatusPendingSync;
  bool isPhotoPendingSync;
  String? offlinePhotoPath;
  Session? session;
  Class? datumClass;
  dynamic house;
  Section? section;
  String? offlineFieldsJson;

  StudentDetailsData({
    this.id,
    this.uuid,
    this.schoolId,
    this.uidNo,
    this.srNo,
    this.panNo,
    this.name,
    this.email,
    this.phone,
    this.whatsappPhone,
    this.landLineNo,
    this.photo,
    this.signature,
    this.barcodePhoto,
    this.dob,
    this.dobTimestamp,
    this.gender,
    this.bloodGroup,
    this.schoolClassId,
    this.schoolHouseId,
    this.schoolSessionId,
    this.schoolClassSectionId,
    this.transportMode,
    this.regNo,
    this.rollNo,
    this.aadharNo,
    this.admissionNo,
    this.rfidNo,
    this.countryId,
    this.stateId,
    this.cityId,
    this.address,
    this.pincode,
    this.loginId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.fatherName,
    this.fatherEmail,
    this.fatherPhone,
    this.fatherWphone,
    this.fatherPhoto,
    this.fatherSignature,
    this.motherName,
    this.motherEmail,
    this.motherPhone,
    this.motherWphone,
    this.motherPhoto,
    this.motherSignature,
    this.relation,
    this.guardianName,
    this.guardianEmail,
    this.guardianPhone,
    this.guardianWhatsappPhone,
    this.guardianPhoto,
    this.guardianSignature,
    this.studentNicId,
    this.caste,
    this.isRteStudent,
    this.religion,
    this.missingFields,
    this.profilePhotoUrl,
    this.pdfProfilePhotoUrl,
    this.signatureUrl,
    this.fatherPhotoUrl,
    this.fatherSignatureUrl,
    this.motherPhotoUrl,
    this.motherSignatureUrl,
    this.isOffline = false,
    this.isExtra = false,
    this.isOfflineUpdate = false,
    this.isExtraPendingSync = false,
    this.isDeletePendingSync = false,
    this.isStatusPendingSync = false,
    this.isPhotoPendingSync = false,
    this.offlinePhotoPath,
    this.session,
    this.datumClass,
    this.house,
    this.section,
    this.offlineFieldsJson,
  });

  StudentDetailsData copyWith({
    String? profilePhotoUrl,
    bool clearProfilePhotoUrl = false,
    String? name,
    String? fatherName,
    String? fatherPhone,
    dynamic fatherWphone,
    String? motherName,
    dynamic motherPhone,
    String? dob,
    String? address,
    dynamic pincode,
    dynamic caste,
    dynamic studentNicId,
    dynamic uidNo,
    dynamic landLineNo,
    dynamic whatsappPhone,
    dynamic email,
    dynamic phone,
    dynamic religion,
    int? status,
    dynamic aadharNo,
    dynamic rollNo,
    dynamic regNo,
    String? srNo,
    dynamic rfidNo,
    dynamic admissionNo,
    dynamic panNo,
    dynamic schoolHouseId,
    dynamic transportMode,
    dynamic isRteStudent,
    dynamic bloodGroup,
    dynamic gender,
    dynamic fatherEmail,
    dynamic motherEmail,
    dynamic motherWphone,
    dynamic fatherWphoneNew,
    int? schoolClassId,
    int? schoolClassSectionId,
    bool? isOffline,
    bool? isExtra,
    bool? isOfflineUpdate,
    bool? isExtraPendingSync,
    bool? isDeletePendingSync,
    bool? isStatusPendingSync,
    bool? isPhotoPendingSync,
    String? offlinePhotoPath,
    bool clearOfflinePhotoPath = false,
    String? uuid,
    Session? session,
    Class? datumClass,
    Section? section,
    String? offlineFieldsJson,
  }) {
    return StudentDetailsData(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      caste: caste ?? this.caste,
      studentNicId: studentNicId ?? this.studentNicId,
      uidNo: uidNo ?? this.uidNo,
      landLineNo: landLineNo ?? this.landLineNo,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      religion: religion ?? this.religion,
      status: status ?? this.status,
      aadharNo: aadharNo ?? this.aadharNo,
      rollNo: rollNo ?? this.rollNo,
      regNo: regNo ?? this.regNo,
      srNo: srNo ?? this.srNo,
      rfidNo: rfidNo ?? this.rfidNo,
      admissionNo: admissionNo ?? this.admissionNo,
      panNo: panNo ?? this.panNo,
      schoolHouseId: schoolHouseId ?? this.schoolHouseId,
      transportMode: transportMode ?? this.transportMode,
      isRteStudent: isRteStudent ?? this.isRteStudent,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      gender: gender ?? this.gender,
      fatherEmail: fatherEmail ?? this.fatherEmail,
      motherEmail: motherEmail ?? this.motherEmail,
      motherWphone: motherWphone ?? this.motherWphone,
      schoolClassId: schoolClassId ?? this.schoolClassId,
      schoolClassSectionId: schoolClassSectionId ?? this.schoolClassSectionId,
      isOffline: isOffline ?? this.isOffline,
      isExtra: isExtra ?? this.isExtra,
      isOfflineUpdate: isOfflineUpdate ?? this.isOfflineUpdate,
      isExtraPendingSync: isExtraPendingSync ?? this.isExtraPendingSync,
      isDeletePendingSync: isDeletePendingSync ?? this.isDeletePendingSync,
      isStatusPendingSync: isStatusPendingSync ?? this.isStatusPendingSync,
      isPhotoPendingSync: isPhotoPendingSync ?? this.isPhotoPendingSync,
      offlinePhotoPath: clearOfflinePhotoPath ? null : (offlinePhotoPath ?? this.offlinePhotoPath),
      session: session ?? this.session,
      datumClass: datumClass ?? this.datumClass,
      section: section ?? this.section,
      // unchanged fields:
      id: id,
      //   uuid: uuid,
      schoolId: schoolId,
      photo: photo,
      signature: signature,
      barcodePhoto: barcodePhoto,
      dobTimestamp: dobTimestamp,
      schoolSessionId: schoolSessionId,
      countryId: countryId,
      stateId: stateId,
      cityId: cityId,
      loginId: loginId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      fatherPhoto: fatherPhoto,
      fatherSignature: fatherSignature,
      motherPhoto: motherPhoto,
      motherSignature: motherSignature,
      relation: relation,
      missingFields: missingFields,
      guardianName: guardianName,
      guardianEmail: guardianEmail,
      guardianPhone: guardianPhone,
      guardianWhatsappPhone: guardianWhatsappPhone,
      guardianPhoto: guardianPhoto,
      guardianSignature: guardianSignature,
      profilePhotoUrl: clearProfilePhotoUrl ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      pdfProfilePhotoUrl: pdfProfilePhotoUrl,
      signatureUrl: signatureUrl,
      fatherPhotoUrl: fatherPhotoUrl,
      fatherSignatureUrl: fatherSignatureUrl,
      motherPhotoUrl: motherPhotoUrl,
      motherSignatureUrl: motherSignatureUrl,
      house: house,
      offlineFieldsJson: offlineFieldsJson ?? this.offlineFieldsJson,
    );
  }

  static dynamic _firstOf(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null && v.toString().isNotEmpty) return v;
    }
    return null;
  }

  factory StudentDetailsData.fromJson(Map<String, dynamic> json) =>
      StudentDetailsData(
        id: json["id"],
        uuid: json["uuid"],
        schoolId: json["school_id"] is int
            ? json["school_id"]
            : int.tryParse(json["school_id"]?.toString() ?? ''),

        panNo: _firstOf(json, ['pan_no', 'pen_number', 'pan_number']),

        regNo: _firstOf(json, ['reg_no', 'registration_number']),


        rollNo: _firstOf(json, ['roll_no', 'roll_number']),

        srNo: _firstOf(json, ['sr_no', 'sr_number'])?.toString(),

        rfidNo: _firstOf(json, ['rfid_no', 'rfid_number']),

        admissionNo: _firstOf(json, ['admission_no', 'admission_number']),

        aadharNo: _firstOf(json, ['aadhar_no', 'aadhar_card_number']),

        uidNo: _firstOf(json, ['uid_no', 'uid_number']),

        landLineNo: _firstOf(json, ['land_line_no', 'landline_contact_number', 'landline_number']),

        whatsappPhone: _firstOf(json, ['whatsapp_phone', 'student_whatsapp_number', 'student_whatsapp']),

        studentNicId: _firstOf(json, ['student_nic_id', 'nic_id']),

        fatherWphone: _firstOf(json, ['father_wphone', 'father_whatsapp_number', 'father_whatsapp']),

        motherWphone: _firstOf(json, ['mother_wphone', 'mother_whatsapp_number', 'mother_whatsapp']),

        name: json["name"],
        email: json["email"],
        phone: json["phone"],
        photo: json["photo"],
        signature: json["signature"],
        barcodePhoto: json["barcode_photo"],
        dob: json["dob"],
        dobTimestamp: json["dob_timestamp"],
        gender: json["gender"],
        bloodGroup: json["blood_group"],
        schoolClassId: json["school_class_id"] is int
            ? json["school_class_id"]
            : int.tryParse(json["school_class_id"]?.toString() ?? ''),
        schoolHouseId: json["school_house_id"],
        schoolSessionId: json["school_session_id"] is int
            ? json["school_session_id"]
            : int.tryParse(json["school_session_id"]?.toString() ?? ''),
        schoolClassSectionId: json["school_class_section_id"] is int
            ? json["school_class_section_id"]
            : int.tryParse(json["school_class_section_id"]?.toString() ?? ''),
        transportMode: json["transport_mode"],
        countryId: json["country_id"],
        stateId: json["state_id"],
        cityId: json["city_id"],
        address: json["address"],
        pincode: json["pincode"],
        loginId: json["login_id"],
        status: json["status"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        deletedAt: json["deleted_at"],
        fatherName: json["father_name"],
        fatherEmail: json["father_email"],
        fatherPhone: json["father_phone"],
        fatherPhoto: json["father_photo"],
        fatherSignature: json["father_signature"],
        motherName: json["mother_name"],
        motherEmail: json["mother_email"],
        motherPhone: json["mother_phone"],
        motherPhoto: json["mother_photo"],
        motherSignature: json["mother_signature"],
        relation: json["relation"],
        guardianName: json["guardian_name"],
        guardianEmail: json["guardian_email"],
        guardianPhone: json["guardian_phone"],
        guardianWhatsappPhone: json["guardian_whatsapp_phone"],
        guardianPhoto: json["guardian_photo"],
        guardianSignature: json["guardian_signature"],
        caste: json["caste"],
        isRteStudent: json["is_rte_student"],
        religion: json["religion"],
        missingFields: json["missing_fields"] == null
            ? []
            : List<String>.from(json["missing_fields"]),
        profilePhotoUrl: json["profile_photo_url"],
        pdfProfilePhotoUrl: json["pdf_profile_photo_url"],
        signatureUrl: json["signature_url"],
        fatherPhotoUrl: json["father_photo_url"],
        fatherSignatureUrl: json["father_signature_url"],
        motherPhotoUrl: json["mother_photo_url"],
        motherSignatureUrl: json["mother_signature_url"],
        isOffline: json["is_offline"] == 1 || json["is_offline"] == true,
        isExtra: json["is_extra"] == 1 || json["is_extra"] == true,
        isOfflineUpdate: json["is_offline_update"] == 1 || json["is_offline_update"] == true,
        isPhotoPendingSync: json["is_photo_pending_sync"] == 1 || json["is_photo_pending_sync"] == true,
        offlinePhotoPath: json["offline_photo_path"],
        session: json["session"] == null ? null : Session.fromJson(json["session"]),
        datumClass: json["class"] == null ? null : Class.fromJson(json["class"]),
        house: json["house"],
        section: json["section"] == null ? null : Section.fromJson(json["section"]),
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "school_id": schoolId,
    "uid_no": uidNo,
    "sr_no": srNo,
    "pan_no": panNo,
    "name": name,
    "email": email,
    "phone": phone,
    "whatsapp_phone": whatsappPhone,
    "land_line_no": landLineNo,
    "photo": photo,
    "signature": signature,
    "barcode_photo": barcodePhoto,
    "dob": dob,
    "dob_timestamp": dobTimestamp,
    "gender": gender,
    "blood_group": bloodGroup,
    "school_class_id": schoolClassId,
    "school_house_id": schoolHouseId,
    "school_session_id": schoolSessionId,
    "school_class_section_id": schoolClassSectionId,
    "transport_mode": transportMode,
    "reg_no": regNo,
    "roll_no": rollNo,
    "aadhar_no": aadharNo,
    "admission_no": admissionNo,
    "rfid_no": rfidNo,
    "country_id": countryId,
    "state_id": stateId,
    "city_id": cityId,
    "address": address,
    "pincode": pincode,
    "login_id": loginId,
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "father_name": fatherName,
    "father_email": fatherEmail,
    "father_phone": fatherPhone,
    "father_wphone": fatherWphone,
    "father_photo": fatherPhoto,
    "father_signature": fatherSignature,
    "mother_name": motherName,
    "mother_email": motherEmail,
    "mother_phone": motherPhone,
    "mother_wphone": motherWphone,
    "mother_photo": motherPhoto,
    "mother_signature": motherSignature,
    "relation": relation,
    "guardian_name": guardianName,
    "guardian_email": guardianEmail,
    "guardian_phone": guardianPhone,
    "guardian_whatsapp_phone": guardianWhatsappPhone,
    "guardian_photo": guardianPhoto,
    "guardian_signature": guardianSignature,
    "student_nic_id": studentNicId,
    "caste": caste,
    "is_rte_student": isRteStudent,
    "religion": religion,
    "missing_fields": missingFields,
    "profile_photo_url": profilePhotoUrl,
    "pdf_profile_photo_url": pdfProfilePhotoUrl,
    "signature_url": signatureUrl,
    "father_photo_url": fatherPhotoUrl,
    "father_signature_url": fatherSignatureUrl,
    "mother_photo_url": motherPhotoUrl,
    "mother_signature_url": motherSignatureUrl,
    "is_offline": isOffline ? 1 : 0,
    "is_extra": isExtra ? 1 : 0,
    "is_offline_update": isOfflineUpdate ? 1 : 0,
    "is_photo_pending_sync": isPhotoPendingSync ? 1 : 0,
    "offline_photo_path": offlinePhotoPath,
    "session": session?.toJson(),
    "class": datumClass?.toJson(),
    "house": house,
    "section": section?.toJson(),
  };
}

class Class {
  int? id;
  String? uuid;
  String? name;
  String? nameWithprefix;
  List<int>? sectionsIds;
  dynamic classTeachers;
  int? schoolId;
  int? classPrefixId;
  int? status;
  int? priority;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  dynamic startTime;
  dynamic endTime;
  dynamic sendMessageTime;
  dynamic extra;
  List<Section>? sections;
  Section? classPrefix;

  Class({
    this.id,
    this.uuid,
    this.name,
    this.nameWithprefix,
    this.sectionsIds,
    this.classTeachers,
    this.schoolId,
    this.classPrefixId,
    this.status,
    this.priority,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.startTime,
    this.endTime,
    this.sendMessageTime,
    this.extra,
    this.sections,
    this.classPrefix,
  });

  factory Class.fromJson(Map<String, dynamic> json) => Class(
    id: json["id"],
    uuid: json["uuid"],
    name: json["name"],
    nameWithprefix: json["name_withprefix"],
    sectionsIds: json["sections_ids"] == null
        ? []
        : List<int>.from(json["sections_ids"]!.map((x) => x)),
    classTeachers: json["class_teachers"],
    schoolId: json["school_id"],
    classPrefixId: json["class_prefix_id"],
    status: json["status"],
    priority: json["priority"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    startTime: json["start_time"],
    endTime: json["end_time"],
    sendMessageTime: json["send_message_time"],
    extra: json["extra"],
    sections: json["sections"] == null
        ? []
        : List<Section>.from(
        json["sections"]!.map((x) => Section.fromJson(x))),
    classPrefix: json["class_prefix"] == null
        ? null
        : Section.fromJson(json["class_prefix"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "name": name,
    "name_withprefix": nameWithprefix,
    "sections_ids": sectionsIds == null
        ? []
        : List<dynamic>.from(sectionsIds!.map((x) => x)),
    "class_teachers": classTeachers,
    "school_id": schoolId,
    "class_prefix_id": classPrefixId,
    "status": status,
    "priority": priority,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "start_time": startTime,
    "end_time": endTime,
    "send_message_time": sendMessageTime,
    "extra": extra,
    "sections": sections == null
        ? []
        : List<dynamic>.from(sections!.map((x) => x.toJson())),
    "class_prefix": classPrefix?.toJson(),
  };
}

class Section {
  int? id;
  String? uuid;
  int? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  int? schoolId;
  String? name;

  Section({
    this.id,
    this.uuid,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.schoolId,
    this.name,
  });

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    id: json["id"],
    uuid: json["uuid"],
    status: json["status"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    schoolId: json["school_id"],
    name: json["name"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "status": status,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "school_id": schoolId,
    "name": name,
  };
}

enum SectionName { A, B }

final sectionNameValues = EnumValues({"A": SectionName.A, "B": SectionName.B});

enum Prefix { ALPHA_NUMERIC }

final prefixValues = EnumValues({"Alpha Numeric": Prefix.ALPHA_NUMERIC});

enum NameWithprefix { THE_10_TH, THE_1_ST }

final nameWithprefixValues = EnumValues(
    {"10th": NameWithprefix.THE_10_TH, "1st": NameWithprefix.THE_1_ST});

class Session {
  int? id;
  String? uuid;
  int? schoolId;
  String? name;
  DateTime? sessionStart;
  DateTime? sessionEnd;
  int? status;
  int? isSubjectWiseAttendence;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;

  Session({
    this.id,
    this.uuid,
    this.schoolId,
    this.name,
    this.sessionStart,
    this.sessionEnd,
    this.status,
    this.isSubjectWiseAttendence,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json["id"],
    uuid: json["uuid"],
    schoolId: json["school_id"],
    name: json["name"],
    sessionStart: json["session_start"] == null
        ? null
        : DateTime.parse(json["session_start"]),
    sessionEnd: json["session_end"] == null
        ? null
        : DateTime.parse(json["session_end"]),
    status: json["status"],
    isSubjectWiseAttendence: json["is_subject_wise_attendence"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "uuid": uuid,
    "school_id": schoolId,
    "name": name,
    "session_start": sessionStart?.toIso8601String(),
    "session_end": sessionEnd?.toIso8601String(),
    "status": status,
    "is_subject_wise_attendence": isSubjectWiseAttendence,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
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

  factory Link.fromJson(Map<String, dynamic> json) => Link(
    url: json["url"],
    label: json["label"],
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

class Filters {
  List<ClassOption>? classOptions;
  dynamic search;
  dynamic status;
  dynamic gender;
  dynamic classFilters;
  bool? showDeleted;

  Filters({
    this.classOptions,
    this.search,
    this.status,
    this.gender,
    this.classFilters,
    this.showDeleted,
  });

  factory Filters.fromJson(Map<String, dynamic> json) => Filters(
    classOptions: json["class_options"] == null
        ? []
        : List<ClassOption>.from(
        json["class_options"]!.map((x) => ClassOption.fromJson(x))),
    search: json["search"],
    status: json["status"],
    gender: json["gender"],
    classFilters: json["class_filters"],
    showDeleted: json["show_deleted"],
  );

  Map<String, dynamic> toJson() => {
    "class_options": classOptions == null
        ? []
        : List<dynamic>.from(classOptions!.map((x) => x.toJson())),
    "search": search,
    "status": status,
    "gender": gender,
    "class_filters": classFilters,
    "show_deleted": showDeleted,
  };
}

class ClassOption {
  String? value;
  String? label;

  ClassOption({
    this.value,
    this.label,
  });

  factory ClassOption.fromJson(Map<String, dynamic> json) => ClassOption(
    value: json["value"],
    label: json["label"],
  );

  Map<String, dynamic> toJson() => {
    "value": value,
    "label": label,
  };
}

class Meta {
  int? currentPage;
  int? lastPage;
  int? perPage;
  int? total;

  Meta({
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    currentPage: json["current_page"],
    lastPage: json["last_page"],
    perPage: json["per_page"],
    total: json["total"],
  );

  Map<String, dynamic> toJson() => {
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
    "total": total,
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

