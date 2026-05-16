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
      version: 6,
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
          is_extra INTEGER DEFAULT 0
        )
        ''');

        await db.execute(
            'CREATE INDEX idx_class_section ON students(school_class_id, school_class_section_id)');
        await db.execute('CREATE INDEX idx_name ON students(name)');

        await _createFormDataTable(db);
        await _createSchoolsTable(db);
        await _createHomeCacheTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createFormDataTable(db);
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE school_form_fields ADD COLUMN roles_json TEXT');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          await _createSchoolsTable(db);
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE students ADD COLUMN is_offline INTEGER DEFAULT 0');
          } catch (_) {}
          await _createHomeCacheTable(db);
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE students ADD COLUMN is_extra INTEGER DEFAULT 0');
          } catch (_) {}
        }
      },
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_school_id ON schools(id)');
  }
}

