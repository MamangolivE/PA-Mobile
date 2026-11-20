// Model catatan rakitan PC yang disimpan di SQLite (perangkat pengguna).
// Setiap catatan milik satu akun (uid) agar tidak tercampur antarakun
class Catatan {
  final int? id; // null = belum pernah disimpan (diisi SQLite saat insert)
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

  Catatan copyWith({
    int? id,
    String? judul,
    String? isi,
    DateTime? diubah,
    bool? disematkan,
  }) {
    return Catatan(
      id: id ?? this.id,
      uid: uid,
      judul: judul ?? this.judul,
      isi: isi ?? this.isi,
      diubah: diubah ?? this.diubah,
      disematkan: disematkan ?? this.disematkan,
    );
  }

  // Model -> baris tabel. SQLite tidak punya bool dan DateTime:
  // bool disimpan sebagai 1/0, waktu sebagai milidetik.
  // Model -> baris tabel. SQLite tidak punya bool dan DateTime:
  // bool disimpan sebagai 1/0, waktu sebagai milidetik.
  Map<String, Object?> keBaris() {
    return {
      'id': id,
      'uid': uid,
      'judul': judul,
      'isi': isi,
      'diubah': diubah.millisecondsSinceEpoch,
      'disematkan': disematkan ? 1 : 0,
    };
  }

  // Baris tabel -> Model (untuk SQLite)
  factory Catatan.dariBaris(Map<String, Object?> baris) {
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

  // JSON -> Model (Disesuaikan dengan DummyJSON /posts)
  factory Catatan.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': final int id,
        'title': final String judul,
        'body': final String isi,
        'userId': final int userId,
      } =>
        Catatan(
          id: id,
          uid: userId.toString(),
          judul: judul,
          isi: isi,
          diubah: DateTime.now(), // DummyJSON tidak punya field tanggal
          disematkan: false,
        ),
      _ => throw FormatException('Bentuk JSON tidak sesuai: $json'),
    };
  }

  // Model -> JSON (Disesuaikan dengan DummyJSON /posts/add)
  Map<String, dynamic> toJson() {
    return {
      'title': judul,
      'body': isi,
      'userId': int.tryParse(uid) ?? 1,
    };
  }
}