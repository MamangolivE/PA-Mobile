import 'package:pa_mobile/domain/models/catatan.dart';
import 'package:pa_mobile/domain/models/hasil.dart';

abstract class RepositoriCatatan {
  Future<Hasil<List<Catatan>>> ambilSemua(String uid, {String kataKunci = ''});
  Future<Hasil<int>> hitung(String uid);
  Future<Hasil<Catatan>> tambah(
      String uid, {
        required String judul,
        required String isi,
      });
  Future<Hasil<void>> ubah(Catatan catatan);
  Future<Hasil<void>> hapus(Catatan catatan);
  Future<Hasil<void>> pulihkan(Catatan catatan);
}