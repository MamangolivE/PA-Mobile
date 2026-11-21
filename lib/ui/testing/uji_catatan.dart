import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pa_mobile/data/repositories/repositori_catatan_impl.dart';
import 'package:pa_mobile/data/services/layanan_api.dart';
import 'package:pa_mobile/data/services/layanan_basis_data.dart';
import 'package:pa_mobile/domain/models/catatan.dart';
import 'package:pa_mobile/domain/models/hasil.dart';
import 'package:pa_mobile/data/repositories/repositori_catatan.dart';
import 'package:pa_mobile/domain/usecases/catatan_usecases.dart';

class FakeRepositoriCatatan implements RepositoriCatatan {
  final List<Catatan> _items = [];
  int _nextId = 1;
  bool harusGagal = false;

  @override
  Future<Hasil<List<Catatan>>> ambilSemua(
      String uid, {
        String kataKunci = '',
      }) async {
    if (harusGagal) {
      return const Gagal(Kegagalan('Simulasi gagal ambil data'));
    }
    final q = kataKunci.trim().toLowerCase();
    final hasil = _items.where((c) {
      if (c.uid != uid) return false;
      if (q.isEmpty) return true;
      return c.judul.toLowerCase().contains(q) ||
          c.isi.toLowerCase().contains(q);
    }).toList();
    return Berhasil(hasil);
  }

  @override
  Future<Hasil<int>> hitung(String uid) async {
    if (harusGagal) {
      return const Gagal(Kegagalan('Simulasi gagal hitung data'));
    }
    return Berhasil(_items.where((c) => c.uid == uid).length);
  }

  @override
  Future<Hasil<Catatan>> tambah(
      String uid, {
        required String judul,
        required String isi,
      }) async {
    if (harusGagal) {
      return const Gagal(Kegagalan('Simulasi gagal tambah data'));
    }
    final baru = Catatan(
      id: _nextId++,
      uid: uid,
      judul: judul,
      isi: isi,
      diubah: DateTime(2026, 11, 21, 10, 0),
    );
    _items.add(baru);
    return Berhasil(baru);
  }

  @override
  Future<Hasil<void>> ubah(Catatan catatan) async {
    if (harusGagal) {
      return const Gagal(Kegagalan('Simulasi gagal ubah data'));
    }
    final idx = _items.indexWhere((c) => c.id == catatan.id);
    if (idx != -1) _items[idx] = catatan;
    return const Berhasil(null);
  }

  @override
  Future<Hasil<void>> hapus(Catatan catatan) async {
    if (harusGagal) {
      return const Gagal(Kegagalan('Simulasi gagal hapus data'));
    }
    _items.removeWhere((c) => c.id == catatan.id);
    return const Berhasil(null);
  }

  @override
  Future<Hasil<void>> pulihkan(Catatan catatan) async {
    if (harusGagal) {
      return const Gagal(Kegagalan('Simulasi gagal pulihkan data'));
    }
    _items.add(catatan);
    return const Berhasil(null);
  }
}

Future<void> jalankanUjiCatatan() async {
  int gagal = 0;

  void periksa(String nama, bool lulus) {
    debugPrint('${lulus ? 'LULUS' : 'GAGAL'}  $nama');
    if (!lulus) gagal++;
  }

  // 1. Uji Use Case & Aturan Bisnis murni memakai FakeRepositoriCatatan
  final fakeRepo = FakeRepositoriCatatan();
  final simpanUseCase = SimpanCatatanUseCase(
    fakeRepo,
    sekarang: () => DateTime(2026, 11, 21, 11, 0),
  );
  final muatUseCase = MuatDaftarCatatanUseCase(fakeRepo);

  final validasiKosong = Catatan.validasiKonten(judul: '   ', isi: '  ');
  periksa('Aturan bisnis menolak catatan kosong', validasiKosong is Gagal);

  final hasilSimpanFake = await simpanUseCase.tambah(
    uid: 'u1',
    judul: '  Rakit PC Gaming ',
    isi: 'Ryzen 7, RX 7800 XT',
  );
  periksa(
    'Use case menyimpan catatan valid lewat FakeRepo',
    hasilSimpanFake is Berhasil<Catatan>,
  );

  if (hasilSimpanFake case Berhasil<Catatan>(:final data)) {
    final disematkan = data.toggleSematkan(DateTime(2026, 11, 21, 11, 5));
    await fakeRepo.ubah(disematkan);
    periksa('Toggle sematkan memperbarui status & waktu', disematkan.disematkan);
  }

  final hasilRingkasan = await muatUseCase.panggil('u1');
  switch (hasilRingkasan) {
    case Berhasil<RingkasanCatatan>(:final data):
      periksa(
        'Use case memuat ringkasan & mengurutkan tersemat di atas',
        data.total == 1 && data.daftar.first.disematkan,
      );
    case Gagal<RingkasanCatatan>(:final kegagalan):
      periksa('Use case muat ringkasan (${kegagalan.pesan})', false);
  }

  // 2. Uji Integrasi RepositoriCatatanImpl + LayananApi + DB In-Memory
  final LayananApi layanan = LayananApi();
  final LayananBasisData layananLokal =
  LayananBasisData(namaBerkas: inMemoryDatabasePath);
  final RepositoriCatatan repo = RepositoriCatatanImpl(
    layananApi: layanan,
    layananLokal: layananLokal,
    sekarang: () => DateTime(2026, 11, 21, 10, 51),
  );

  try {
    final hasilTambah = await repo.tambah(
      '1',
      judul: 'Rakit gaming',
      isi: 'Ryzen 5, RTX 4060',
    );
    switch (hasilTambah) {
      case Berhasil<Catatan>(:final data):
        periksa('Berhasil menambah catatan (API menjawab)', data.id != null);
      case Gagal<Catatan>(:final kegagalan):
        periksa('Berhasil menambah catatan (${kegagalan.pesan})', false);
    }

    final hasilAmbil = await repo.ambilSemua('1');
    switch (hasilAmbil) {
      case Berhasil<List<Catatan>>(:final data):
        periksa('Berhasil mengambil daftar catatan dari API', data.isNotEmpty);
      case Gagal<List<Catatan>>(:final kegagalan):
        periksa('Berhasil mengambil daftar catatan (${kegagalan.pesan})', false);
    }

    final hasilCari = await repo.ambilSemua('1', kataKunci: 'love');
    switch (hasilCari) {
      case Berhasil<List<Catatan>>(:final data):
        periksa('Fitur pencarian API berfungsi', data.isNotEmpty);
      case Gagal<List<Catatan>>(:final kegagalan):
        periksa('Fitur pencarian API (${kegagalan.pesan})', false);
    }
  } catch (galat) {
    debugPrint('GAGAL  Pemeriksaan berhenti karena galat: $galat');
    gagal++;
  } finally {
    layanan.tutup();
    await layananLokal.tutup();
  }

  debugPrint(
    gagal == 0
        ? 'Semua pemeriksaan catatan LULUS.'
        : '$gagal pemeriksaan catatan GAGAL.',
  );
}