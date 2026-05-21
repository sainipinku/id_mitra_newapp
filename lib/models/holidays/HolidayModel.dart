class HolidayModel {
  final int? id;
  final String? name;
  final List<String> dates; // API returns date as array
  final String? type;
  final int? year;
  final String? description;
  final bool? isActive;

  const HolidayModel({
    this.id,
    this.name,
    this.dates = const [],
    this.type,
    this.year,
    this.description,
    this.isActive,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    // date can be a List or a single String
    List<String> parsedDates = [];
    final raw = json['date'];
    if (raw is List) {
      parsedDates = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      parsedDates = [raw];
    }

    // type can be inside extra.type or directly
    String? type;
    final extra = json['extra'];
    if (extra is Map && extra['type'] != null) {
      type = extra['type'].toString();
    } else {
      type = json['type']?.toString();
    }

    return HolidayModel(
      id: json['id'],
      name: json['name']?.toString(),
      dates: parsedDates,
      type: type,
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
      description: json['description']?.toString(),
      isActive: json['is_active'] != null
          ? (json['is_active'] == true || json['is_active'] == 1)
          : true,
    );
  }

  /// First date as DateTime (for calendar display)
  DateTime? get firstDateTime {
    if (dates.isEmpty) return null;
    try { return DateTime.parse(dates.first); } catch (_) { return null; }
  }

  /// All dates as DateTime list
  List<DateTime> get dateTimes {
    return dates.map((d) {
      try { return DateTime.parse(d); } catch (_) { return null; }
    }).whereType<DateTime>().toList();
  }

  /// For backward compat
  DateTime? get dateTime => firstDateTime;
}
