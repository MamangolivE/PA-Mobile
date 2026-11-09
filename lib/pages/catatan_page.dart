import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/pages/catatan_form_page.dart';
import 'package:pa_mobile/providers/catatan_provider.dart';
import 'package:pa_mobile/theme/app_colors.dart';
import 'package:pa_mobile/utils/format_date.dart';

// Halaman daftar catatan rakitan PC. Datanya disimpan di SQLite pada perangkat
// (tidak diunggah ke server) dan dipisahkan per akun.
class CatatanPage extends StatefulWidget {
  const CatatanPage({super.key});

  @override
  State<CatatanPage> createState() => _CatatanPageState();
}

class _CatatanPageState extends State<CatatanPage> {
  final TextEditingController _pencarian = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pencarian selalu mulai dari kosong setiap halaman dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CatatanProvider>().cari('');
    });
  }

  @override
  void dispose() {
    _pencarian.dispose();
    super.dispose();
  }

  void _bukaForm({Catatan? catatan}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatatanFormPage(catatan: catatan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CatatanProvider vm = context.watch<CatatanProvider>();
    // Warna ikon/teks di atas warna aksen: gelap pada mode gelap, putih pada mode terang.
    final Color onAccent =
    context.isDarkMode ? AppColorsDark.background : Colors.white;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'Catatan Rakit PC',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(),
        backgroundColor: context.appPrimary,
        foregroundColor: onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Catatan baru',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Kotak pencarian (LIKE di SQLite, tidak membedakan huruf besar/kecil).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorderSubtle),
                ),
                child: TextField(
                  controller: _pencarian,
                  onChanged: vm.cari,
                  style: TextStyle(color: context.appTextPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Cari catatan',
                    hintStyle: TextStyle(color: context.appTextMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: context.appOutline),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.phone_android_rounded, size: 13, color: context.appTextMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tersimpan di perangkat ini • ${vm.total} catatan',
                      style: TextStyle(fontSize: 11, color: context.appTextMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _isi(vm)),
          ],
        ),
      ),
    );
  }

  Widget _isi(CatatanProvider vm) {
    // Menunggu pembacaan pertama dari database.
    if (vm.memuat && vm.daftar.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Gagal membaca database.
    if (vm.pesanGalat != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vm.pesanGalat!, style: TextStyle(color: context.appDanger)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => vm.muat(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    // Kosong: belum ada catatan, atau pencarian tidak menemukan apa pun.
    if (vm.daftar.isEmpty) {
      final bool mencari = vm.kataKunci.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mencari ? Icons.search_off_rounded : Icons.sticky_note_2_outlined,
                size: 64,
                color: context.appBorder,
              ),
              const SizedBox(height: 12),
              Text(
                mencari ? 'Catatan tidak ditemukan' : 'Belum ada catatan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mencari
                    ? 'Coba kata kunci lain.'
                    : 'Tekan Catatan baru untuk mencatat daftar komponen rakitan, harga, atau rencana upgrade.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
      itemCount: vm.daftar.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _kartu(vm, vm.daftar[index]),
    );
  }

  // Satu kartu catatan: ketuk untuk mengubah, geser ke kiri untuk menghapus.
  Widget _kartu(CatatanProvider vm, Catatan catatan) {
    final Color warnaIkonHapus =
    context.isDarkMode ? AppColorsDark.background : Colors.white;

    return Dismissible(
      key: ValueKey(catatan.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: context.appDanger,
          borderRadius: AppStyle.card,
        ),
        child: Icon(Icons.delete_outline_rounded, color: warnaIkonHapus),
      ),
      onDismissed: (_) {
        vm.hapus(catatan);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Catatan dihapus'),
              action: SnackBarAction(
                label: 'Urungkan',
                onPressed: () => vm.pulihkan(catatan),
              ),
            ),
          );
      },
      child: Material(
        color: context.appSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppStyle.card,
          side: BorderSide(color: context.appBorderSubtle),
        ),
        child: InkWell(
          onTap: () => _bukaForm(catatan: catatan),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catatan.judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      if (catatan.isi.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          catatan.isi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        formatTanggal(catatan.diubah),
                        style: TextStyle(fontSize: 10, color: context.appTextMuted),
                      ),
                    ],
                  ),
                ),
                // Sematkan: catatan penting selalu di paling atas.
                IconButton(
                  tooltip: catatan.disematkan ? 'Lepas sematan' : 'Sematkan',
                  onPressed: () => vm.sematkan(catatan),
                  icon: Icon(
                    catatan.disematkan
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 20,
                    color: catatan.disematkan
                        ? context.appPrimary
                        : context.appOutline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}