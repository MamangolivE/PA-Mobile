import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/repositories/repositori_catatan.dart';
import 'package:pa_mobile/services/layanan_basis_data.dart';

// Pemeriksaan otomatis untuk repository catatan. Hanya dijalankan di mode debug.
// Memakai database di MEMORI (inMemoryDatabasePath): SQL yang diuji sama persis
// dengan yang dipakai aplikasi, tetapi catatan asli di perangkat tidak tersentuh.
// Hasilnya tampil di konsol: baris "LULUS" / "GAGAL".
Future<void> jalankanUjiCatatan() async {
  final LayananBasisData layanan =
  LayananBasisData(namaBerkas: inMemoryDatabasePath);
  final RepositoriCatatan repo = RepositoriCatatan(layanan: layanan);
  int gagal = 0;

  void periksa(String nama, bool lulus) {
    debugPrint('${lulus ? 'LULUS' : 'GAGAL'}  $nama');
    if (!lulus) gagal++;
  }

  try {
    final Catatan a = await repo.tambah(
      'akun_a',
      judul: 'Rakit gaming',
      isi: 'Ryzen 5, RTX 4060',
    );
    final Catatan b = await repo.tambah(
      'akun_a',
      judul: "Jum'at servis",
      isi: 'Bersihkan fan',
    );
    await repo.tambah('akun_b', judul: 'Catatan akun B', isi: 'rahasia');

    periksa('Catatan pertama mendapat id 1', a.id == 1);
    periksa('Catatan kedua mendapat id 2', b.id == 2);

    List<Catatan> daftar = await repo.ambilSemua('akun_a');
    periksa('Akun A hanya melihat 2 catatan miliknya', daftar.length == 2);
    periksa('Yang terbaru di atas', daftar.first.id == b.id);
    periksa(
      'Jumlah dihitung per akun',
      await repo.hitung('akun_a') == 2 && await repo.hitung('akun_b') == 1,
    );

    daftar = await repo.ambilSemua('akun_a', kataKunci: 'rtx');
    periksa('Cari tidak membedakan huruf besar', daftar.length == 1);

    daftar = await repo.ambilSemua('akun_a', kataKunci: "Jum'at");
    periksa('Tanda kutip tidak merusak SQL', daftar.length == 1);

    await repo.ubah(a.copyWith(disematkan: true));
    daftar = await repo.ambilSemua('akun_a');
    periksa('Yang disematkan naik ke atas', daftar.first.id == a.id);

    // Akun lain mencoba menghapus catatan akun A: harus gagal diam-diam.
    await repo.hapus(
      Catatan(id: a.id, uid: 'akun_b', judul: '', isi: '', diubah: DateTime.now()),
    );
    periksa(
      'Akun lain tidak bisa menghapus catatan akun A',
      (await repo.ambilSemua('akun_a')).any((Catatan c) => c.id == a.id),
    );

    await repo.hapus(b);
    periksa('Tersisa 1 setelah dihapus', await repo.hitung('akun_a') == 1);

    await repo.pulihkan(b);
    daftar = await repo.ambilSemua('akun_a');
    periksa('Urungkan: kembali dengan id lamanya', daftar.any((Catatan c) => c.id == b.id));
  } catch (galat) {
    debugPrint('GAGAL  Pemeriksaan berhenti karena galat: $galat');
    gagal++;
  } finally {
    await layanan.tutup();
  }

  debugPrint(
    gagal == 0
        ? 'Semua pemeriksaan catatan LULUS.'
        : '$gagal pemeriksaan catatan GAGAL.',
  );
}