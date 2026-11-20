import 'package:sqflite/sqflite.dart';

// Layanan yang membuka database SQLite lokal SEKALI saja.
// Databasenya satu berkas di perangkat di Chrome: tersimpan di IndexedDB.
class LayananBasisData {
  LayananBasisData({this.namaBerkas = 'bengkelkom_lokal.db'});

  final String namaBerkas;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _buka();

  Future<Database> _buka() {
    return openDatabase(
      namaBerkas,
      version: 2, // Naik ke versi 2 untuk migrasi
      onCreate: (Database db, int versi) async {
        await db.execute('''
          CREATE TABLE catatan (
            id         INTEGER PRIMARY KEY,
            uid        TEXT NOT NULL,
            judul      TEXT NOT NULL,
            isi        TEXT NOT NULL,
            diubah     INTEGER NOT NULL,
            disematkan INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (Database db, int versiLama, int versiBaru) async {
        if (versiLama < 2) {
          // Contoh migrasi skema jika ada perubahan tabel di masa depan
          // Misal: ALTER TABLE catatan ADD COLUMN baru TEXT;
        }
      },
    );
  }

  Future<void> tutup() async {
    final Future<Database>? terbuka = _database;
    if (terbuka == null) return;
    _database = null;
    try {
      await (await terbuka).close();
    } catch (_) {
      // Database gagal dibuka sejak awal: tidak ada yang perlu ditutup.
    }
  }
}