import 'package:pa_mobile/domain/models/hasil.dart';

class Catatan {
  final int? id;
  final String uid;
  final String judul;
  final String isi;
  final DateTime diubah;
  final bool disematkan;

  const Catatan({
    this.id,
    required this.uid,
    required this.judul,
    required this.isi,
    required this.diubah,
    this.disematkan = false,
  });

  static const int batasJudul = 120;
  static const int batasIsi = 5000;

  static Hasil<({String judul, String isi})> validasiKonten({
    required String judul,
    required String isi,
  }) {
    final String judulBersih = judul.trim();
    final String isiBersih = isi.trim();

    if (judulBersih.isEmpty && isiBersih.isEmpty) {
      return const Gagal(
        Kegagalan('Judul atau isi catatan wajib diisi.'),
      );
    }
    if (judulBersih.length > batasJudul) {
      return const Gagal(
        Kegagalan('Judul catatan maksimal $batasJudul karakter.'),
      );
    }
    if (isiBersih.length > batasIsi) {
      return const Gagal(
        Kegagalan('Isi catatan maksimal $batasIsi karakter.'),
      );
    }

    return Berhasil((
    judul: judulBersih.isEmpty ? 'Tanpa Judul' : judulBersih,
    isi: isiBersih,
    ));
  }

  Catatan toggleSematkan(DateTime waktu) {
    return Catatan(
      id: id,
      uid: uid,
      judul: judul,
      isi: isi,
      diubah: waktu,
      disematkan: !disematkan,
    );
  }

  Catatan copyWith({
    int? id,
    String? uid,
    String? judul,
    String? isi,
    DateTime? diubah,
    bool? disematkan,
  }) {
    return Catatan(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      judul: judul ?? this.judul,
      isi: isi ?? this.isi,
      diubah: diubah ?? this.diubah,
      disematkan: disematkan ?? this.disematkan,
    );
  }
}