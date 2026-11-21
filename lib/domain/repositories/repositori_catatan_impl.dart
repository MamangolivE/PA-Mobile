import 'package:sqflite/sqflite.dart';
import 'package:pa_mobile/data/services/layanan_api.dart';
import 'package:pa_mobile/data/services/layanan_basis_data.dart';
import 'package:pa_mobile/domain/models/catatan.dart';
import 'package:pa_mobile/domain/models/hasil.dart';
import 'package:pa_mobile/domain/repositories/repositori_catatan.dart';

class RepositoriCatatanImpl implements RepositoriCatatan {
  RepositoriCatatanImpl({
    required LayananApi layananApi,
    required LayananBasisData layananLokal,
    DateTime Function()? sekarang,
  })  : _layananApi = layananApi,
        _layananLokal = layananLokal,
        _sekarang = sekarang ?? DateTime.now;

  final LayananApi _layananApi;
  final LayananBasisData _layananLokal;
  final DateTime Function() _sekarang;
  static const String _tabel = 'catatan';

  Map<String, Object?> _keBaris(Catatan catatan) {
    return {
      if (catatan.id != null) 'id': catatan.id,
      'uid': catatan.uid,
      'judul': catatan.judul,
      'isi': catatan.isi,
      'diubah': catatan.diubah.millisecondsSinceEpoch,
      'disematkan': catatan.disematkan ? 1 : 0,
    };
  }

  Catatan _dariBaris(Map<String, Object?> baris) {
    return switch (baris) {
      {
      'id': final int id,
      'uid': final String uid,
      'judul': final String judul,
      'isi': final String isi,
      'diubah': final int diubah,
      'disematkan': final int disematkan,
      } =>
          Catatan(
            id: id,
            uid: uid,
            judul: judul,
            isi: isi,
            diubah: DateTime.fromMillisecondsSinceEpoch(diubah),
            disematkan: disematkan == 1,
          ),
      _ => throw FormatException('Baris catatan tidak sesuai: $baris'),
    };
  }

  Map<String, dynamic> _keJson(Catatan catatan) {
    return {
      'title': catatan.judul,
      'body': catatan.isi,
      'userId': int.tryParse(catatan.uid) ?? 1,
    };
  }

  @override
  Future<Hasil<List<Catatan>>> ambilSemua(
      String uid, {
        String kataKunci = '',
      }) async {
    try {
      final Database db = await _layananLokal.database;
      final String kunci = kataKunci.trim();

      final baris = await db.query(
    _tabel,
    where: kunci.isEmpty
    ? 'uid = ?'
        : 'uid = ? AND (judul LIKE ? OR isi LIKE ?)',
    whereArgs: kunci.isEmpty
    ? [uid]
        : [uid, '%$kunci%', '%$kunci%'],
    orderBy: 'disematkan DESC, diubah DESC, id DESC',
    );

    return Berhasil(baris.map(_dariBaris).toList());
    } catch (e) {
    return Gagal(
    Kegagalan('Gagal memuat catatan lokal.', penyebab: e),
    );
    }
  }

  @override
  Future<Hasil<int>> hitung(String uid) async {
    try {
      final Database db = await _layananLokal.database;
      final int total = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_tabel WHERE uid = ?',
          [uid],
        ),
      ) ??
          0;
      return Berhasil(total);
    } catch (e) {
      return Gagal(Kegagalan('Gagal menghitung catatan.', penyebab: e));
    }
  }

  @override
  Future<Hasil<Catatan>> tambah(
      String uid, {
        required String judul,
        required String isi,
      }) async {
    final baru = Catatan(
      uid: uid,
      judul: judul,
      isi: isi,
      diubah: _sekarang(),
    );

    try {
      final Database db = await _layananLokal.database;
      final int id = await db.insert(
        _tabel,
        _keBaris(baru),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final tersimpan = baru.copyWith(id: id);

      // Kirim ke API secara opsional/sinkronisasi ringan tanpa mengalahkan data lokal.
      try {
        await _layananApi.post('/posts/add', _keJson(tersimpan));
      } catch (_) {}

      return Berhasil(tersimpan);
    } catch (e) {
      return Gagal(Kegagalan('Gagal menambah catatan.', penyebab: e));
    }
  }

  @override
  Future<Hasil<void>> ubah(Catatan catatan) async {
    try {
      final Database db = await _layananLokal.database;
      await db.update(
        _tabel,
        _keBaris(catatan),
        where: 'id = ? AND uid = ?',
        whereArgs: [catatan.id, catatan.uid],
      );

      try {
        await _layananApi.post('/posts/${catatan.id}', _keJson(catatan));
      } catch (_) {}

      return const Berhasil(null);
    } catch (e) {
      return Gagal(Kegagalan('Gagal mengubah catatan.', penyebab: e));
    }
  }

  @override
  Future<Hasil<void>> hapus(Catatan catatan) async {
    try {
      final Database db = await _layananLokal.database;
      await db.delete(
        _tabel,
        where: 'id = ? AND uid = ?',
        whereArgs: [catatan.id, catatan.uid],
      );

      try {
        await _layananApi.post('/posts/${catatan.id}', {'isDeleted': true});
      } catch (_) {}

      return const Berhasil(null);
    } catch (e) {
      return Gagal(Kegagalan('Gagal menghapus catatan.', penyebab: e));
    }
  }

  @override
  Future<Hasil<void>> pulihkan(Catatan catatan) async {
    try {
      final Database db = await _layananLokal.database;
      await db.insert(
        _tabel,
        _keBaris(catatan),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Berhasil(null);
    } catch (e) {
      return Gagal(Kegagalan('Gagal memulihkan catatan.', penyebab: e));
    }
  }
}