import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/repositories/repositori_catatan.dart';

// ViewModel catatan rakitan PC. Data diambil dari SQLite lokal
// dan dipisahkan per akun yang sedang login.
class CatatanProvider extends ChangeNotifier {
  CatatanProvider({required RepositoriCatatan repositori})
      : _repositori = repositori {
    // Memantau login: catatan dimuat saat login dan dibersihkan saat logout.
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  final RepositoriCatatan _repositori;
  StreamSubscription<User?>? _authSubscription;

  String? _uid;
  List<Catatan> _daftar = [];
  int _total = 0;
  String _kataKunci = '';
  bool _memuat = true;
  String? _pesanGalat;
  bool _sudahDibuang = false;
  int _nomorPermintaan = 0;

  List<Catatan> get daftar => List.unmodifiable(_daftar);
  int get total => _total;
  bool get memuat => _memuat;
  String? get pesanGalat => _pesanGalat;
  String get kataKunci => _kataKunci;

  void _onAuthChanged(User? user) {
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _kataKunci = '';
    _daftar = [];
    _total = 0;
    _pesanGalat = null;

    if (_uid == null) {
      _memuat = false;
      notifyListeners();
      return;
    }
    muat();
  }

  // Membaca ulang daftar dari database.
  Future<void> muat({bool tampilkanMemuat = true}) async {
    final String? uid = _uid;
    if (uid == null) return;

    // Penjaga jawaban terlambat: hanya permintaan terbaru yang dipakai.
    final int nomor = ++_nomorPermintaan;
    if (tampilkanMemuat) {
      _memuat = true;
      _pesanGalat = null;
      notifyListeners();
    }

    try {
      final List<Catatan> daftar =
      await _repositori.ambilSemua(uid, kataKunci: _kataKunci);
      final int total = await _repositori.hitung(uid);
      if (_sudahDibuang || nomor != _nomorPermintaan) return;
      _daftar = daftar;
      _total = total;
      _pesanGalat = null;
    } catch (galat) {
      if (_sudahDibuang || nomor != _nomorPermintaan) return;
      debugPrint('Galat saat membaca catatan: $galat');
      _pesanGalat = 'Gagal membaca catatan dari perangkat.';
    }
    _memuat = false;
    notifyListeners();
  }

  void cari(String kata) {
    if (kata == _kataKunci) return;
    _kataKunci = kata;
    muat(tampilkanMemuat: false);
  }

  // Menjalankan satu perintah tulis, lalu SELALU membaca ulang dari database,
  // sehingga tampilan selalu sama dengan isi database.
  Future<bool> _tulis(Future<void> Function() perintah) async {
    bool berhasil = true;
    try {
      await perintah();
    } catch (galat) {
      debugPrint('Galat saat menulis catatan: $galat');
      berhasil = false;
    }
    await muat(tampilkanMemuat: false);
    return berhasil;
  }

  Future<bool> tambah(String judul, String isi) {
    final String? uid = _uid;
    if (uid == null) return Future.value(false);
    return _tulis(
          () => _repositori.tambah(uid, judul: judul.trim(), isi: isi.trim()),
    );
  }

  Future<bool> ubah(Catatan lama, String judul, String isi) {
    return _tulis(
          () => _repositori.ubah(
        lama.copyWith(
          judul: judul.trim(),
          isi: isi.trim(),
          diubah: DateTime.now(),
        ),
      ),
    );
  }

  Future<bool> sematkan(Catatan catatan) {
    return _tulis(
          () => _repositori.ubah(catatan.copyWith(disematkan: !catatan.disematkan)),
    );
  }

  // Dismissible mewajibkan baris langsung hilang dari daftar saat digeser,
  // jadi daftar di memori dibuang dulu, baru database dihapus.
  Future<bool> hapus(Catatan catatan) {
    _daftar = _daftar.where((Catatan c) => c.id != catatan.id).toList();
    _total = _total > 0 ? _total - 1 : 0;
    notifyListeners();
    return _tulis(() => _repositori.hapus(catatan));
  }

  Future<bool> pulihkan(Catatan catatan) {
    return _tulis(() => _repositori.pulihkan(catatan));
  }

  @override
  void dispose() {
    _sudahDibuang = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}