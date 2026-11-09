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
  Map<String, Object?> keBaris() {
    return {
      'id': ?id,
      'uid': uid,
      'judul': judul,
      'isi': isi,
      'diubah': diubah.millisecondsSinceEpoch,
      'disematkan': disematkan ? 1 : 0,
    };
  }

  // Baris tabel = Model.
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
}