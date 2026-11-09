import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pa_mobile/models/catatan.dart';
import 'package:pa_mobile/providers/catatan_provider.dart';
import 'package:pa_mobile/theme/app_colors.dart';

// Formulir untuk menambah catatan baru atau mengubah catatan yang ada.
class CatatanFormPage extends StatefulWidget {
  final Catatan? catatan; // null = catatan baru

  const CatatanFormPage({super.key, this.catatan});

  @override
  State<CatatanFormPage> createState() => _CatatanFormPageState();
}

class _CatatanFormPageState extends State<CatatanFormPage> {
  late final TextEditingController _judul;
  late final TextEditingController _isi;
  bool _menyimpan = false;
  String _galat = '';

  @override
  void initState() {
    super.initState();
    _judul = TextEditingController(text: widget.catatan?.judul ?? '');
    _isi = TextEditingController(text: widget.catatan?.isi ?? '');
  }

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final String judul = _judul.text.trim();
    final String isi = _isi.text.trim();
    if (judul.isEmpty) {
      setState(() => _galat = 'Judul wajib diisi');
      return;
    }

    setState(() {
      _menyimpan = true;
      _galat = '';
    });

    final CatatanProvider vm = context.read<CatatanProvider>();
    final bool berhasil = widget.catatan == null
        ? await vm.tambah(judul, isi)
        : await vm.ubah(widget.catatan!, judul, isi);

    if (!mounted) return;
    if (berhasil) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _menyimpan = false;
        _galat = 'Gagal menyimpan catatan. Coba lagi.';
      });
    }
  }

  InputDecoration _dekorasi(String hint) {
    OutlineInputBorder garis(Color warna) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: warna),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.appTextMuted, fontSize: 13),
      filled: true,
      fillColor: context.appSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: garis(context.appBorder),
      enabledBorder: garis(context.appBorder),
      focusedBorder: garis(context.appPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool baru = widget.catatan == null;
    final Color onAccent =
    context.isDarkMode ? AppColorsDark.background : Colors.white;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text(
          baru ? 'Catatan Baru' : 'Ubah Catatan',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Judul',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _judul,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                style: TextStyle(color: context.appTextPrimary),
                decoration: _dekorasi('Contoh: Rakit PC Gaming 8 Juta')
                    .copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),
              Text(
                'Isi catatan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _isi,
                minLines: 8,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: context.appTextPrimary),
                decoration: _dekorasi(
                  'Daftar komponen, perkiraan harga, atau rencana upgrade...',
                ),
              ),
              if (_galat.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _galat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.appDanger,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _menyimpan ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: context.appPrimary,
                    foregroundColor: onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _menyimpan
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Simpan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}