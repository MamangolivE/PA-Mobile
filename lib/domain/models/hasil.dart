class Kegagalan {
  final String pesan;
  final Object? penyebab;

  const Kegagalan(this.pesan, {this.penyebab});

  @override
  String toString() => 'Kegagalan($pesan)';
}

sealed class Hasil<T> {
  const Hasil();
}

final class Berhasil<T> extends Hasil<T> {
  final T data;
  const Berhasil(this.data);
}

final class Gagal<T> extends Hasil<T> {
  final Kegagalan kegagalan;
  const Gagal(this.kegagalan);
}