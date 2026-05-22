import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'students.db');

    return await openDatabase(
      path,
      version: 29,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE students (
          id INTEGER PRIMARY KEY,
          uuid TEXT,
          school_id INTEGER,
          name TEXT,
          email TEXT,
          phone TEXT,
          gender TEXT,
          school_class_id INTEGER,
          school_class_section_id INTEGER,
          father_name TEXT,
          father_phone TEXT,
          mother_name TEXT,
          mother_phone TEXT,
          profile_photo_url TEXT,
          address TEXT,
          status INTEGER,

          missing_fields TEXT,
          session_json TEXT,
          class_json TEXT,
          section_json TEXT,
          house_json TEXT,

          raw_data TEXT,
          is_offline INTEGER DEFAULT 0,
          is_extra INTEGER DEFAULT 0,
          is_offline_update INTEGER DEFAULT 0,
          is_extra_pending_sync INTEGER DEFAULT 0,
          is_delete_pending_sync INTEGER DEFAULT 0,
          is_status_pending_sync INTEGER DEFAULT 0,
          is_photo_pending_sync INTEGER DEFAULT 0,
          offline_photo_path TEXT,
          offline_fields_json TEXT,

          created_at TEXT,
          updated_at TEXT
        )
        ''');

        await db.execute(
            'CREATE INDEX idx_class_section ON students(school_class_id, school_class_section_id)');

        await db.execute(
            'CREATE INDEX idx_name ON students(name)');

        await db.execute(
            'CREATE INDEX idx_students_uuid ON students(uuid)');

        await db.execute(
            'CREATE INDEX idx_students_updated_at ON students(updated_at)');

        await _createFormDataTable(db);
        await _createSchoolsTable(db);
        await _createHomeCacheTable(db);
        await _createCorrectionTable(db);
        await _createPendingChecklistTable(db);
        await _createPendingOrdersTable(db);
        await _createPendingDownloadsTable(db);
        await _createDownloadColumnsTable(db);
        await _createOrdersTable(db);
        await _createPendingStatusUpdatesTable(db);
        await _createSchoolClassesTable(db);
        await _createImageSettingsTable(db);
        await _createPendingImageSettingsTable(db);
        await _createStaffTable(db);
        await _createStaffCorrectionTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 29) {
          // Add staff_uuid column to staff_corrections for deduplication of offline placeholders
          try {
            await db.execute(
              'ALTER TABLE staff_corrections ADD COLUMN staff_uuid TEXT',
            );
          } catch (_) {}
        }

        if (oldVersion < 28) {
          // Add is_offline column to orders table for offline staff order support
          try {
            await db.execute(
              'ALTER TABLE orders ADD COLUMN is_offline INTEGER DEFAULT 0',
            );
          } catch (_) {}
        }

        if (oldVersion < 27) {
          // Add staff_json column to pending_checklists for offline staff process checklist
          try {
            await db.execute(
              'ALTER TABLE pending_checklists ADD COLUMN staff_json TEXT',
            );
          } catch (_) {}
        }

        if (oldVersion < 26) {
          // Fix: Recreate students table if it was never created due to duplicate column bug
          try {
            await db.execute('SELECT 1 FROM students LIMIT 1');
          } catch (_) {
            // Table doesn't exist — create it now with correct schema
            await db.execute('''
            CREATE TABLE IF NOT EXISTS students (
              id INTEGER PRIMARY KEY,
              uuid TEXT,
              school_id INTEGER,
              name TEXT,
              email TEXT,
              phone TEXT,
              gender TEXT,
              school_class_id INTEGER,
              school_class_section_id INTEGER,
              father_name TEXT,
              father_phone TEXT,
              mother_name TEXT,
              mother_phone TEXT,
              profile_photo_url TEXT,
              address TEXT,
              status INTEGER,
              missing_fields TEXT,
              session_json TEXT,
              class_json TEXT,
              section_json TEXT,
              house_json TEXT,
              raw_data TEXT,
              is_offline INTEGER DEFAULT 0,
              is_extra INTEGER DEFAULT 0,
              offline_fields_json TEXT,
              is_offline_update INTEGER DEFAULT 0,
              is_extra_pending_sync INTEGER DEFAULT 0,
              is_delete_pending_sync INTEGER DEFAULT 0,
              is_status_pending_sync INTEGER DEFAULT 0,
              is_photo_pending_sync INTEGER DEFAULT 0,
              offline_photo_path TEXT,
              created_at TEXT,
              updated_at TEXT
            )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_class_section ON students(school_class_id, school_class_section_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_name ON students(name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_students_uuid ON students(uuid)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_students_updated_at ON students(updated_at)');
          }
        }

        if (oldVersion < 25) {
          await _createStaffTable(db);
          await _createStaffCorrectionTable(db);
        }

        if (oldVersion < 24) {
          await _createStaffCorrectionTable(db);
        }

        if (oldVersion < 23) {
          try {
            await db.execute(
              'ALTER TABLE staff ADD COLUMN offline_fields_json TEXT',
            );
          } catch (_) {}
        }

        if (oldVersion < 22) {
          await _createStaffTable(db);
        }

        if (oldVersion < 2) {
          await _createFormDataTable(db);
        }

        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE school_form_fields ADD COLUMN roles_json TEXT',
            );
          } catch (_) {}
        }

        if (oldVersion < 4) {
          await _createSchoolsTable(db);
        }

        if (oldVersion < 5) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_offline INTEGER DEFAULT 0',
            );
          } catch (_) {}

          await _createHomeCacheTable(db);
        }

        if (oldVersion < 6) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_extra INTEGER DEFAULT 0',
            );
          } catch (_) {}
        }

        if (oldVersion < 7) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN offline_fields_json TEXT',
            );
          } catch (_) {}
        }

        if (oldVersion < 8) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_offline_update INTEGER DEFAULT 0',
            );
          } catch (_) {}
        }

        if (oldVersion < 9) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_extra_pending_sync INTEGER DEFAULT 0',
            );
          } catch (_) {}
        }

        if (oldVersion < 10) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_delete_pending_sync INTEGER DEFAULT 0',
            );
          } catch (_) {}

          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_status_pending_sync INTEGER DEFAULT 0',
            );
          } catch (_) {}
        }

        if (oldVersion < 11) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN is_photo_pending_sync INTEGER DEFAULT 0',
            );
          } catch (_) {}

          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN offline_photo_path TEXT',
            );
          } catch (_) {}
        }

        if (oldVersion < 12) {
          await _createCorrectionTable(db);
        }

        if (oldVersion < 13) {
          await _createPendingChecklistTable(db);
        }

        if (oldVersion < 14) {
          await _createPendingOrdersTable(db);
        }

        if (oldVersion < 15) {
          await _createPendingDownloadsTable(db);
        }

        if (oldVersion < 16) {
          await _createDownloadColumnsTable(db);
        }

        if (oldVersion < 17) {
          await _createOrdersTable(db);
        }

        if (oldVersion < 18) {
          await _createPendingStatusUpdatesTable(db);
        }

        if (oldVersion < 19) {
          await _createSchoolClassesTable(db);
        }

        if (oldVersion < 20) {
          await _createImageSettingsTable(db);
          await _createPendingImageSettingsTable(db);
        }

        if (oldVersion < 21) {
          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN created_at TEXT',
            );
          } catch (_) {}

          try {
            await db.execute(
              'ALTER TABLE students ADD COLUMN updated_at TEXT',
            );
          } catch (_) {}

          try {
            await db.execute(
              'CREATE INDEX idx_students_uuid ON students(uuid)',
            );
          } catch (_) {}

          try {
            await db.execute(
              'CREATE INDEX idx_students_updated_at ON students(updated_at)',
            );
          } catch (_) {}
        }
      },
    );
  }

  static Future<void> _createImageSettingsTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS image_settings (
          school_id TEXT PRIMARY KEY,
          settings_json TEXT,
          updated_at INTEGER
        )
        ''');
  }

  static Future<void> _createPendingImageSettingsTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_image_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_id TEXT,
          body_json TEXT,
          created_at INTEGER
        )
        ''');
  }

  static Future<void> _createSchoolClassesTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS school_classes (
          school_id TEXT PRIMARY KEY,
          classes_json TEXT,
          updated_at INTEGER
        )
        ''');
  }

  static Future<void> _createPendingStatusUpdatesTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_status_updates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_id TEXT,
          uuids_json TEXT,
          status TEXT,
          issue_note TEXT,
          created_at INTEGER
        )
        ''');
  }

  static Future<void> _createOrdersTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS orders (
          id INTEGER PRIMARY KEY,
          uuid TEXT,
          school_id INTEGER,
          status TEXT,
          type TEXT,
          ordered_at TEXT,
          received_at_short TEXT,
          student_card INTEGER,
          student_card_qty INTEGER,
          parent_card INTEGER,
          admit_card INTEGER,
          printing_issue TEXT,
          delivered_at TEXT,
          cancelled_at TEXT,
          school_json TEXT,
          student_json TEXT,
          staff_json TEXT,
          raw_data TEXT,
          is_offline INTEGER DEFAULT 0,
          updated_at INTEGER
        )
        ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_school_id ON orders(school_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_uuid ON orders(uuid)',
    );
  }

  static Future<void> _createDownloadColumnsTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS download_columns (
          school_id TEXT PRIMARY KEY,
          columns_json TEXT,
          updated_at INTEGER
        )
        ''');
  }

  static Future<void> _createPendingDownloadsTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_downloads (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_id TEXT,
          list_type TEXT,
          selected_columns_json TEXT,
          created_at INTEGER
        )
        ''');
  }

  static Future<void> _createPendingOrdersTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_id TEXT,
          card_type TEXT,
          card_for_json TEXT,
          card_users_json TEXT,
          order_json TEXT,
          created_at INTEGER
        )
        ''');
  }

  static Future<void> _createPendingChecklistTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_checklists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_id TEXT,
          process_type TEXT,
          list_type TEXT,
          card_type TEXT,
          card_for TEXT,
          students_json TEXT,
          staff_json TEXT,
          created_at INTEGER
        )
        ''');
  }

  static Future<void> _createStaffCorrectionTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_corrections (
          id INTEGER PRIMARY KEY,
          uuid TEXT,
          staff_uuid TEXT,
          school_id INTEGER,
          status TEXT,
          remark TEXT,
          staff_name TEXT,
          raw_data TEXT,
          updated_at INTEGER
        )
        ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_staff_corrections_school_id ON staff_corrections(school_id)',
    );
  }

  static Future<void> _createCorrectionTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS correction_students (
          id INTEGER PRIMARY KEY,
          uuid TEXT,
          status TEXT,
          remark TEXT,
          student_id INTEGER,
          school_id INTEGER,
          name TEXT,
          email TEXT,
          phone TEXT,
          reg_no TEXT,
          roll_no TEXT,
          admission_no TEXT,
          dob TEXT,
          address TEXT,
          father_name TEXT,
          father_phone TEXT,
          mother_name TEXT,
          mother_phone TEXT,
          school_class_id INTEGER,
          school_class_section_id INTEGER,
          profile_photo_url TEXT,
          class_json TEXT,
          section_json TEXT,
          raw_data TEXT,
          updated_at INTEGER
        )
        ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_correction_school_id ON correction_students(school_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_correction_uuid ON correction_students(uuid)',
    );
  }

  static Future<void> _createFormDataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS school_form_data (
        school_id TEXT PRIMARY KEY,
        sessions_json TEXT,
        classes_json TEXT,
        houses_json TEXT,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS school_form_fields (
        school_id TEXT PRIMARY KEY,
        fields_json TEXT,
        available_fields_json TEXT,
        roles_json TEXT,
        updated_at INTEGER
      )
    ''');
  }

  static Future<void> _createHomeCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS home_cache (
        key TEXT PRIMARY KEY,
        json_data TEXT,
        updated_at INTEGER
      )
    ''');
  }

  static Future<void> _createSchoolsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schools (
        id INTEGER PRIMARY KEY,
        raw_json TEXT,
        updated_at INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_school_id ON schools(id)',
    );
  }

  static Future<void> _createStaffTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS staff (
          id INTEGER PRIMARY KEY,
          uuid TEXT,
          school_id INTEGER,
          name TEXT,
          designation TEXT,
          department TEXT,
          email TEXT,
          phone TEXT,
          whatsapp_phone TEXT,
          address TEXT,
          profile_photo_url TEXT,
          role_name TEXT,
          role_id INTEGER,
          status INTEGER,
          assigned_classes_json TEXT,
          dob TEXT,
          father_name TEXT,
          mother_name TEXT,
          husband_name TEXT,
          gender TEXT,
          blood_group TEXT,
          pincode TEXT,
          employee_id TEXT,
          national_code TEXT,
          login_id TEXT,
          date_of_joining TEXT,

          raw_data TEXT,
          is_offline INTEGER DEFAULT 0,
          is_extra INTEGER DEFAULT 0,
          is_offline_update INTEGER DEFAULT 0,
          is_extra_pending_sync INTEGER DEFAULT 0,
          is_delete_pending_sync INTEGER DEFAULT 0,
          is_status_pending_sync INTEGER DEFAULT 0,
          is_photo_pending_sync INTEGER DEFAULT 0,
          offline_photo_path TEXT,
          offline_fields_json TEXT,

          created_at TEXT,
          updated_at TEXT
        )
        ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_school_id ON staff(school_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_name ON staff(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_uuid ON staff(uuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_updated_at ON staff(updated_at)');
  }
}