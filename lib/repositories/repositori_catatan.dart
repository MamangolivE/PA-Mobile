import 'package:sqflite/sqflite.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/services/layanan_api.dart';
import 'package:pa_mobile/services/layanan_basis_data.dart';

// Repositori Hybrid: Strategi "Lokal Dulu / Cache (SQLite), Lalu Update dari Server (API)".
// Sesuai dengan materi Pertemuan 11 - Offline-First Support.
class RepositoriCatatan {
  RepositoriCatatan({
    required LayananApi layananApi,
    required LayananBasisData layananLokal,
  })  : _layananApi = layananApi,
        _layananLokal = layananLokal;

  final LayananApi _layananApi;
  final LayananBasisData _layananLokal;
  static const String _tabel = 'catatan';

  // Strategy: Ambil dari API (server), jika berhasil simpan/update ke SQLite lokal.
  // Jika API error (misal tidak ada internet), ambil data cadangan dari SQLite lokal.
  Future<List<Catatan>> ambilSemua(String uid, {String kataKunci = ''}) async {
    try {
      // 1. Coba ambil data dari API Server
      final path = kataKunci.isEmpty ? '/posts' : '/posts/search?q=$kataKunci';
      final Map<String, dynamic> data = await _layananApi.get(path);
      final List<dynamic> list = data['posts'] ?? [];
      final List<Catatan> daftarApi = list
          .map((item) => Catatan.fromJson(item as Map<String, dynamic>))
          .toList();

      // 2. Berhasil dari API: Simpan/Update data tersebut ke Cache SQLite Lokal
      final Database db = await _layananLokal.database;
      final Batch batch = db.batch();
      for (final Catatan item in daftarApi) {
        batch.insert(
          _tabel,
          item.keBaris(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      return daftarApi;
    } catch (_) {
      // 3. Jika API gagal (Offline/Server Error), fallback membaca dari SQLite Lokal
      return ambilDariLokal(uid, kataKunci: kataKunci);
    }
  }

  // Membaca data langsung dari SQLite lokal
  Future<List<Catatan>> ambilDariLokal(String uid, {String kataKunci = ''}) async {
    final Database db = await _layananLokal.database;
    final String kunci = kataKunci.trim();
    final List<Map<String, Object?>> baris = await db.query(
      _tabel,
      where: kunci.isEmpty
          ? null
          : 'judul LIKE ? OR isi LIKE ?',
      whereArgs: kunci.isEmpty ? null : ['%$kunci%', '%$kunci%'],
      orderBy: 'disematkan DESC, diubah DESC, id DESC',
    );
    return baris.map(Catatan.dariBaris).toList();
  }

  Future<int> hitung(String uid) async {
    try {
      final Map<String, dynamic> data = await _layananApi.get('/posts?limit=0');
      return data['total'] ?? 0;
    } catch (_) {
      final Database db = await _layananLokal.database;
      return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tabel'),
          ) ??
          0;
    }
  }

  Future<Catatan> tambah(String uid, {required String judul, required String isi}) async {
    final baru = Catatan(uid: uid, judul: judul, isi: isi, diubah: DateTime.now());
    try {
      // Simpan ke API
      final res = await _layananApi.post('/posts/add', baru.toJson());
      final catatanTersimpan = Catatan.fromJson(res);
      
      // Simpan juga ke SQLite lokal sebagai Cache
      final Database db = await _layananLokal.database;
      await db.insert(_tabel, catatanTersimpan.keBaris(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      return catatanTersimpan;
    } catch (_) {
      // Offline mode: Simpan ke SQLite saja
      final Database db = await _layananLokal.database;
      final int id = await db.insert(_tabel, baru.keBaris());
      return baru.copyWith(id: id);
    }
  }

  Future<void> ubah(Catatan catatan) async {
    // Update di SQLite lokal dulu
    final Database db = await _layananLokal.database;
    await db.update(
      _tabel,
      catatan.keBaris(),
      where: 'id = ?',
      whereArgs: [catatan.id],
    );

    // Lalu coba sync ke API
    try {
      await _layananApi.post('/posts/${catatan.id}', catatan.toJson());
    } catch (_) {}
  }

  Future<void> hapus(Catatan catatan) async {
    // Hapus di SQLite lokal
    final Database db = await _layananLokal.database;
    await db.delete(
      _tabel,
      where: 'id = ?',
      whereArgs: [catatan.id],
    );

    // Lalu coba sync ke API
    try {
      await _layananApi.post('/posts/${catatan.id}', {'isDeleted': true});
    } catch (_) {}
  }

  Future<void> pulihkan(Catatan catatan) async {
    final Database db = await _layananLokal.database;
    await db.insert(
      _tabel,
      catatan.keBaris(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
