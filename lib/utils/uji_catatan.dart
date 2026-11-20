import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/repositories/repositori_catatan.dart';
import 'package:pa_mobile/services/layanan_api.dart';
import 'package:pa_mobile/services/layanan_basis_data.dart';

// Pemeriksaan otomatis untuk repository catatan. Hanya dijalankan di mode debug.
// Memakai database di MEMORI (inMemoryDatabasePath): SQL yang diuji sama persis
// dengan yang dipakai aplikasi, tetapi catatan asli di perangkat tidak tersentuh.
// Hasilnya tampil di konsol: baris "LULUS" / "GAGAL".
Future<void> jalankanUjiCatatan() async {
  // Gunakan LayananApi untuk pengujian. 
  // Catatan: DummyJSON tidak benar-benar menyimpan data, 
  // jadi beberapa uji (seperti cek ID atau jumlah) mungkin gagal.
  final LayananApi layanan = LayananApi();
  final LayananBasisData layananLokal = LayananBasisData(namaBerkas: inMemoryDatabasePath);
  final RepositoriCatatan repo = RepositoriCatatan(
    layananApi: layanan, 
    layananLokal: layananLokal
  );
  int gagal = 0;

  void periksa(String nama, bool lulus) {
    debugPrint('${lulus ? 'LULUS' : 'GAGAL'}  $nama');
    if (!lulus) gagal++;
  }

  try {
    // Simulasi tambah (DummyJSON /posts/add)
    final Catatan a = await repo.tambah(
      '1', // DummyJSON userId harus angka
      judul: 'Rakit gaming',
      isi: 'Ryzen 5, RTX 4060',
    );
    
    // Periksa apakah server menjawab (id post baru di DummyJSON biasanya 252)
    periksa('Berhasil menambah catatan (API menjawab)', a.id != null);

    List<Catatan> daftar = await repo.ambilSemua('1');
    periksa('Berhasil mengambil daftar catatan dari API', daftar.isNotEmpty);

    daftar = await repo.ambilSemua('1', kataKunci: 'love');
    periksa('Fitur pencarian API berfungsi', daftar.isNotEmpty);

  } catch (galat) {
    debugPrint('GAGAL  Pemeriksaan berhenti karena galat: $galat');
    gagal++;
  } finally {
    layanan.tutup();
  }

  debugPrint(
    gagal == 0
        ? 'Semua pemeriksaan catatan LULUS.'
        : '$gagal pemeriksaan catatan GAGAL.',
  );
}