import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pa_mobile/domain/models/catatan.dart';
import 'package:pa_mobile/domain/models/hasil.dart';
import 'package:pa_mobile/data/repositories/repositori_catatan.dart';
import 'package:pa_mobile/domain/usecases/catatan_usecases.dart';
import 'package:pa_mobile/ui/core/perintah.dart';

class CatatanProvider extends ChangeNotifier {
  CatatanProvider({
    required RepositoriCatatan repositori,
    DateTime Function()? sekarang,
  })  : _repositori = repositori,
        _sekarang = sekarang ?? DateTime.now,
        _muatUseCase = MuatDaftarCatatanUseCase(repositori),
        _simpanUseCase = SimpanCatatanUseCase(
          repositori,
          sekarang: sekarang ?? DateTime.now,
        ) {
    _perintahTambah = Perintah<Catatan>(_eksekusiTambah);
    _perintahUbah = Perintah<void>(_eksekusiUbah);
    _perintahHapus = Perintah<void>(_eksekusiHapus);
    _perintahPulihkan = Perintah<void>(_eksekusiPulihkan);

    final initialUser = FirebaseAuth.instance.currentUser;
    if (initialUser != null) {
      _uid = initialUser.uid;
      muat();
    }

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  final RepositoriCatatan _repositori;
  final DateTime Function() _sekarang;
  final MuatDaftarCatatanUseCase _muatUseCase;
  final SimpanCatatanUseCase _simpanUseCase;

  late final Perintah<Catatan> _perintahTambah;
  late final Perintah<void> _perintahUbah;
  late final Perintah<void> _perintahHapus;
  late final Perintah<void> _perintahPulihkan;

  String? _draftJudul;
  String? _draftIsi;
  Catatan? _draftUbah;
  Catatan? _draftHapus;
  Catatan? _draftPulihkan;

  StreamSubscription<User?>? _authSubscription;
  String? _uid;
  List<Catatan> _daftar = [];
  int _total = 0;
  String _kataKunci = '';
  bool _memuat = true;
  String? _pesanGalat;
  bool _sudahDibuang = false;
  int _nomorPermintaan = 0;

  String? get _aktifUid => _uid ?? FirebaseAuth.instance.currentUser?.uid;

  List<Catatan> get daftar => List.unmodifiable(_daftar);
  int get total => _total;
  bool get memuat => _memuat;
  String? get pesanGalat => _pesanGalat;
  String get kataKunci => _kataKunci;

  bool get sedangMenambah => _perintahTambah.sedangBerjalan;
  bool get sedangMengubah => _perintahUbah.sedangBerjalan;
  bool get sedangMenghapus => _perintahHapus.sedangBerjalan;
  bool get sedangMemulihkan => _perintahPulihkan.sedangBerjalan;
  bool get sedangMemproses =>
      sedangMenambah || sedangMengubah || sedangMenghapus || sedangMemulihkan;

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

  Future<void> muat({bool tampilkanMemuat = true}) async {
    final String? uid = _aktifUid;
    if (uid == null) {
      _memuat = false;
      notifyListeners();
      return;
    }
    _uid = uid;

    final int nomor = ++_nomorPermintaan;
    if (tampilkanMemuat) {
      _memuat = true;
      _pesanGalat = null;
      notifyListeners();
    }

    final hasil = await _muatUseCase.panggil(uid, kataKunci: _kataKunci);
    if (_sudahDibuang || nomor != _nomorPermintaan) return;

    switch (hasil) {
      case Berhasil(:final data):
        _daftar = data.daftar;
        _total = data.total;
        _pesanGalat = null;
      case Gagal(:final kegagalan):
        debugPrint('Galat saat membaca catatan: ${kegagalan.pesan}');
        _pesanGalat = kegagalan.pesan;
    }

    _memuat = false;
    notifyListeners();
  }

  void cari(String kata) {
    if (kata == _kataKunci) return;
    _kataKunci = kata;
    muat(tampilkanMemuat: false);
  }

  Future<Hasil<Catatan>> _eksekusiTambah() async {
    final uid = _aktifUid;
    if (uid == null) {
      return const Gagal(
        Kegagalan('Sesi pengguna tidak ditemukan. Silakan login ulang.'),
      );
    }
    return _simpanUseCase.tambah(
      uid: uid,
      judul: _draftJudul ?? '',
      isi: _draftIsi ?? '',
    );
  }

  Future<Hasil<void>> _eksekusiUbah() async {
    final target = _draftUbah;
    if (target == null) {
      return const Gagal(Kegagalan('Data catatan tidak ditemukan.'));
    }
    if (_draftJudul != null && _draftIsi != null) {
      return _simpanUseCase.ubah(
        lama: target,
        judul: _draftJudul!,
        isi: _draftIsi!,
      );
    }
    return _repositori.ubah(target);
  }

  Future<Hasil<void>> _eksekusiHapus() async {
    final target = _draftHapus;
    if (target == null) {
      return const Gagal(Kegagalan('Data catatan tidak ditemukan.'));
    }
    return _repositori.hapus(target);
  }

  Future<Hasil<void>> _eksekusiPulihkan() async {
    final target = _draftPulihkan;
    if (target == null) {
      return const Gagal(Kegagalan('Data catatan tidak ditemukan.'));
    }
    return _repositori.pulihkan(target);
  }

  Future<bool> tambah(String judul, String isi) async {
    final uid = _aktifUid;
    if (uid == null) {
      _pesanGalat = 'Sesi pengguna tidak ditemukan. Silakan login ulang.';
      notifyListeners();
      return false;
    }
    _uid = uid;
    _draftJudul = judul;
    _draftIsi = isi;
    final hasil = await _perintahTambah.jalankan();
    _draftJudul = null;
    _draftIsi = null;

    switch (hasil) {
      case Berhasil():
        _pesanGalat = null;
        await muat(tampilkanMemuat: false);
        return true;
      case Gagal(:final kegagalan):
        debugPrint(
          'Gagal tambah catatan: ${kegagalan.pesan} (${kegagalan.penyebab})',
        );
        _pesanGalat = kegagalan.pesan;
        notifyListeners();
        return false;
    }
  }

  Future<bool> ubah(Catatan lama, String judul, String isi) async {
    _draftUbah = lama;
    _draftJudul = judul;
    _draftIsi = isi;
    final hasil = await _perintahUbah.jalankan();
    _draftUbah = null;
    _draftJudul = null;
    _draftIsi = null;

    switch (hasil) {
      case Berhasil():
        _pesanGalat = null;
        await muat(tampilkanMemuat: false);
        return true;
      case Gagal(:final kegagalan):
        debugPrint(
          'Gagal ubah catatan: ${kegagalan.pesan} (${kegagalan.penyebab})',
        );
        _pesanGalat = kegagalan.pesan;
        notifyListeners();
        return false;
    }
  }

  Future<bool> sematkan(Catatan catatan) async {
    _draftUbah = catatan.toggleSematkan(_sekarang());
    _draftJudul = null;
    _draftIsi = null;
    final hasil = await _perintahUbah.jalankan();
    _draftUbah = null;

    if (hasil is Gagal<void>) {
      debugPrint('Gagal sematkan catatan: ${hasil.kegagalan.pesan}');
      _pesanGalat = hasil.kegagalan.pesan;
      notifyListeners();
      return false;
    }

    _pesanGalat = null;
    await muat(tampilkanMemuat: false);
    return true;
  }

  Future<bool> hapus(Catatan catatan) async {
    _daftar = _daftar.where((Catatan c) => c.id != catatan.id).toList();
    _total = _total > 0 ? _total - 1 : 0;
    notifyListeners();

    _draftHapus = catatan;
    final hasil = await _perintahHapus.jalankan();
    _draftHapus = null;

    if (hasil is Gagal<void>) {
      debugPrint('Gagal hapus catatan: ${hasil.kegagalan.pesan}');
      _pesanGalat = hasil.kegagalan.pesan;
      await muat(tampilkanMemuat: false);
      return false;
    }

    _pesanGalat = null;
    await muat(tampilkanMemuat: false);
    return true;
  }

  Future<bool> pulihkan(Catatan catatan) async {
    _draftPulihkan = catatan;
    final hasil = await _perintahPulihkan.jalankan();
    _draftPulihkan = null;

    if (hasil is Gagal<void>) {
      debugPrint('Gagal pulihkan catatan: ${hasil.kegagalan.pesan}');
      _pesanGalat = hasil.kegagalan.pesan;
      notifyListeners();
      return false;
    }

    _pesanGalat = null;
    await muat(tampilkanMemuat: false);
    return true;
  }

  @override
  void dispose() {
    _sudahDibuang = true;
    _perintahTambah.dispose();
    _perintahUbah.dispose();
    _perintahHapus.dispose();
    _perintahPulihkan.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }
}