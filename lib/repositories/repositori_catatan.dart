import 'package:sqflite/sqflite.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/services/layanan_basis_data.dart';

// Repository: menerjemahkan antara SQL dan model Catatan.
// ViewModel tidak perlu tahu apa pun tentang SQL.
class RepositoriCatatan {
  RepositoriCatatan({required LayananBasisData layanan}) : _layanan = layanan;

  static const String _tabel = 'catatan';
  final LayananBasisData _layanan;

  // Read: catatan milik satu akun. Yang disematkan di atas, lalu terbaru.
  Future<List<Catatan>> ambilSemua(String uid, {String kataKunci = ''}) async {
    final Database db = await _layanan.database;
    final String kunci = kataKunci.trim();
    final List<Map<String, Object?>> baris = await db.query(
      _tabel,
      // Nilai dikirim lewat whereArgs (tanda ?), BUKAN ditempel ke teks SQL,
      // agar aman dari SQL injection dan dari tanda kutip seperti Jum'at.
      where: kunci.isEmpty
          ? 'uid = ?'
          : 'uid = ? AND (judul LIKE ? OR isi LIKE ?)',
      whereArgs: kunci.isEmpty ? [uid] : [uid, '%$kunci%', '%$kunci%'],
      orderBy: 'disematkan DESC, diubah DESC, id DESC',
    );
    return baris.map(Catatan.dariBaris).toList();
  }

  // Jumlah seluruh catatan milik akun (tanpa terpengaruh pencarian).
  Future<int> hitung(String uid) async {
    final Database db = await _layanan.database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tabel WHERE uid = ?', [uid]),
    ) ??
        0;
  }

  // Create: hasilnya id baris baru.
  Future<Catatan> tambah(
      String uid, {
        required String judul,
        required String isi,
      }) async {
    final Database db = await _layanan.database;
    final Catatan baru = Catatan(
      uid: uid,
      judul: judul,
      isi: isi,
      diubah: DateTime.now(),
    );
    final int id = await db.insert(_tabel, baru.keBaris());
    return baru.copyWith(id: id);
  }

  // Update: mengubah judul, isi, waktu, dan status sematan.
  Future<void> ubah(Catatan catatan) async {
    final Database db = await _layanan.database;
    await db.update(
      _tabel,
      {
        'judul': catatan.judul,
        'isi': catatan.isi,
        'diubah': catatan.diubah.millisecondsSinceEpoch,
        'disematkan': catatan.disematkan ? 1 : 0,
      },
      where: 'id = ? AND uid = ?',
      whereArgs: [catatan.id, catatan.uid],
    );
  }

  // Delete.
  Future<void> hapus(Catatan catatan) async {
    final Database db = await _layanan.database;
    await db.delete(
      _tabel,
      where: 'id = ? AND uid = ?',
      whereArgs: [catatan.id, catatan.uid],
    );
  }

  // Untuk tombol "Urungkan": menyimpan kembali lengkap dengan id lamanya.
  Future<void> pulihkan(Catatan catatan) async {
    final Database db = await _layanan.database;
    await db.insert(
      _tabel,
      catatan.keBaris(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}