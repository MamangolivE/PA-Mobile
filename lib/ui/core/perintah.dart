import 'package:flutter/foundation.dart';
import 'package:pa_mobile/domain/models/hasil.dart';

class Perintah<T> extends ChangeNotifier {
  Perintah(this._aksi);

  final Future<Hasil<T>> Function() _aksi;

  bool _sedangBerjalan = false;
  Hasil<T>? _hasilTerakhir;

  bool get sedangBerjalan => _sedangBerjalan;
  Hasil<T>? get hasilTerakhir => _hasilTerakhir;

  Future<Hasil<T>> jalankan() async {
    if (_sedangBerjalan) {
      return const Gagal(Kegagalan('Proses sedang berjalan.'));
    }

    _sedangBerjalan = true;
    notifyListeners();

    try {
      final hasil = await _aksi();
      _hasilTerakhir = hasil;
      return hasil;
    } finally {
      _sedangBerjalan = false;
      notifyListeners();
    }
  }
}