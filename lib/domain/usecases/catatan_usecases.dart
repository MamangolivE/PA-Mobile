import 'package:pa_mobile/domain/models/catatan.dart';
import 'package:pa_mobile/domain/models/hasil.dart';
import 'package:pa_mobile/data/repositories/repositori_catatan.dart';

class RingkasanCatatan {
  final List<Catatan> daftar;
  final int total;

  const RingkasanCatatan({
    required this.daftar,
    required this.total,
  });
}

class MuatDaftarCatatanUseCase {
  MuatDaftarCatatanUseCase(this._repositori);

  final RepositoriCatatan _repositori;

  Future<Hasil<RingkasanCatatan>> panggil(
      String uid, {
        String kataKunci = '',
      }) async {
    final hasilDaftar = await _repositori.ambilSemua(uid, kataKunci: kataKunci);
    if (hasilDaftar case Gagal<List<Catatan>>(:final kegagalan)) {
      return Gagal(kegagalan);
    }

    final hasilTotal = await _repositori.hitung(uid);
    final int total = switch (hasilTotal) {
      Berhasil<int>(:final data) => data,
      Gagal<int>() => (hasilDaftar as Berhasil<List<Catatan>>).data.length,
    };

    final List<Catatan> terurut = List<Catatan>.from(
      (hasilDaftar as Berhasil<List<Catatan>>).data,
    )..sort((a, b) {
      if (a.disematkan != b.disematkan) {
        return a.disematkan ? -1 : 1;
      }
      return b.diubah.compareTo(a.diubah);
    });

    return Berhasil(RingkasanCatatan(daftar: terurut, total: total));
  }
}

class SimpanCatatanUseCase {
  SimpanCatatanUseCase(
      RepositoriCatatan repositori, {
        DateTime Function()? sekarang,
      })  : _repositori = repositori,
        _sekarang = sekarang ?? DateTime.now;

  final RepositoriCatatan _repositori;
  final DateTime Function() _sekarang;

  Future<Hasil<Catatan>> tambah({
    required String uid,
    required String judul,
    required String isi,
  }) async {
    final validasi = Catatan.validasiKonten(judul: judul, isi: isi);
    switch (validasi) {
      case Gagal(:final kegagalan):
        return Gagal(kegagalan);
      case Berhasil(:final data):
        return _repositori.tambah(uid, judul: data.judul, isi: data.isi);
    }
  }

  Future<Hasil<void>> ubah({
    required Catatan lama,
    required String judul,
    required String isi,
  }) async {
    final validasi = Catatan.validasiKonten(judul: judul, isi: isi);
    switch (validasi) {
      case Gagal(:final kegagalan):
        return Gagal(kegagalan);
      case Berhasil(:final data):
        return _repositori.ubah(
          lama.copyWith(
            judul: data.judul,
            isi: data.isi,
            diubah: _sekarang(),
          ),
        );
    }
  }
}