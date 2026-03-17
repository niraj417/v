import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/lead.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('leads.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
CREATE TABLE leads (
  id $idType,
  placeId $textType UNIQUE,
  name $textType,
  phoneNumber $textTypeNullable,
  address $textTypeNullable,
  website $textTypeNullable,
  status $textType,
  rating REAL
)
''');
  }

  Future<Lead> create(Lead lead) async {
    final db = await instance.database;
    final id = await db.insert('leads', lead.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return lead.copyWith(id: id);
  }

  Future<Lead?> getLead(String placeId) async {
    final db = await instance.database;
    final maps = await db.query(
      'leads',
      columns: ['id', 'placeId', 'name', 'phoneNumber', 'address', 'website', 'status', 'rating'],
      where: 'placeId = ?',
      whereArgs: [placeId],
    );

    if (maps.isNotEmpty) {
      return Lead.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Lead>> readAllLeads() async {
    final db = await instance.database;
    final result = await db.query('leads', orderBy: 'id DESC');
    return result.map((json) => Lead.fromMap(json)).toList();
  }

  Future<List<Lead>> readLeadsByStatus(String status) async {
    final db = await instance.database;
    final result = await db.query(
      'leads',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'id DESC'
    );
    return result.map((json) => Lead.fromMap(json)).toList();
  }

  Future<int> update(Lead lead) async {
    final db = await instance.database;
    return db.update(
      'leads',
      lead.toMap(),
      where: 'id = ?',
      whereArgs: [lead.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'leads',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
