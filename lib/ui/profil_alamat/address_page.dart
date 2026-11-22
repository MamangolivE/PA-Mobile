import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:pa_mobile/domain/models/address.dart';
import 'package:pa_mobile/ui/profil_alamat/address_provider.dart';
import 'package:pa_mobile/ui/core/app_colors.dart';
import 'package:pa_mobile/ui/core/auth_text_field.dart';

// Halaman pengelolaan alamat pengiriman, meliputi penambahan,
// pemilihan alamat utama, dan penghapusan alamat.
class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  // Controller untuk mengambil dan mengatur nilai pada setiap kolom input.
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController detailController = TextEditingController();

  // Menyimpan pesan kesalahan ketika validasi formulir gagal.
  String errorMessage = '';

  // Status proses pengambilan lokasi GPS saat ini
  bool _isLoadingLocation = false;

  // Reverse Geocoding alternatif menggunakan OpenStreetMap Nominatim
  // Digunakan saat di Web (karena package geocoding tidak mendukung Web) atau ketika Geocoder native HP gagal.
  Future<String?> _reverseGeocodeNominatim(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'BengkelKOM-App/1.0 (Mobile App Project)'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];

          final road = address['road'] ?? address['pedestrian'] ?? address['suburb'];
          final houseNumber = address['house_number'];
          if (road != null) {
            parts.add(houseNumber != null ? '$road No. $houseNumber' : '$road');
          }

          final village = address['village'] ?? address['neighbourhood'] ?? address['suburb'] ?? address['quarter'];
          if (village != null && village != road) {
            parts.add('Kel. $village');
          }

          final cityDistrict = address['city_district'] ?? address['district'];
          if (cityDistrict != null && cityDistrict != village) {
            parts.add('Kec. $cityDistrict');
          }

          final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['county'];
          if (city != null) {
            parts.add('$city');
          }

          final state = address['state'];
          if (state != null) {
            parts.add('$state');
          }

          final postcode = address['postcode'];
          if (postcode != null) {
            parts.add('$postcode');
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {}
    return null;
  }

  // Mengambil koordinat GPS dan melakukan reverse-geocoding menjadi alamat teks
  Future<void> _fillCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // 1. Periksa apakah layanan lokasi (GPS) pada perangkat aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layanan lokasi (GPS) belum aktif. Silakan aktifkan GPS perangkat Anda.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2. Periksa dan minta izin akses lokasi
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin akses lokasi ditolak oleh pengguna.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi ditolak secara permanen. Buka pengaturan aplikasi untuk mengizinkan.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3. Dapatkan koordinat lokasi sekarang
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      String? fullAddress;

      // 4. Coba reverse geocoding native (hanya untuk non-Web: Android / iOS)
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final parts = <String>[];

            final street = place.street?.trim() ?? '';
            if (street.isNotEmpty) parts.add(street);

            final subLocality = place.subLocality?.trim() ?? '';
            if (subLocality.isNotEmpty && subLocality != street) {
              parts.add('Kel. $subLocality');
            }

            final locality = place.locality?.trim() ?? '';
            if (locality.isNotEmpty && locality != subLocality) {
              parts.add('Kec. $locality');
            }

            final subAdminArea = place.subAdministrativeArea?.trim() ?? '';
            if (subAdminArea.isNotEmpty) {
              parts.add(subAdminArea);
            }

            final adminArea = place.administrativeArea?.trim() ?? '';
            if (adminArea.isNotEmpty) {
              parts.add(adminArea);
            }

            final postalCode = place.postalCode?.trim() ?? '';
            if (postalCode.isNotEmpty) {
              parts.add(postalCode);
            }

            if (parts.isNotEmpty) {
              fullAddress = parts.join(', ');
            }
          }
        } catch (_) {
          // Jika geocoding native gagal / offline, gunakan fallback di bawah
        }
      }

      // 5. Fallback ke OpenStreetMap jika Web atau jika geocoding native tidak mengembalikan hasil
      fullAddress ??= await _reverseGeocodeNominatim(position.latitude, position.longitude);

      // 6. Jika kedua cara tidak mengembalikan alamat teks, gunakan koordinat angka
      fullAddress ??= 'Titik Koordinat: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      detailController.text = fullAddress;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat berhasil dideteksi dari lokasi perangkat!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendapatkan lokasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    // Melepaskan controller untuk menghindari penggunaan memori yang tidak diperlukan.
    nameController.dispose();
    phoneController.dispose();
    detailController.dispose();
    super.dispose();
  }

  // Memvalidasi formulir dan menyimpan alamat melalui AddressProvider.
  void saveAddress() {
    // Memastikan seluruh kolom telah diisi sebelum alamat disimpan.
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        detailController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Semua kolom wajib diisi');
      return;
    }

    // Memanggil fungsi addAddress tanpa berlangganan perubahan data provider.
    context.read<AddressProvider>().addAddress(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      detail: detailController.text.trim(),
    );

    // Mengosongkan formulir setelah alamat berhasil dikirim ke provider.
    nameController.clear();
    phoneController.clear();
    detailController.clear();

    // Menghapus pesan kesalahan setelah proses penyimpanan.
    setState(() => errorMessage = '');
  }

  @override
  Widget build(BuildContext context) {
    // Warna ikon/teks di atas warna aksen: gelap pada mode gelap, putih pada mode terang.
    final onAccent = context.isDarkMode ? AppColorsDark.background : Colors.white;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'Alamat Pengiriman',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        // Consumer memperbarui tampilan ketika data alamat pada provider berubah.
        child: Consumer<AddressProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form untuk memasukkan informasi alamat pengiriman baru.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        border: Border.all(color: context.appBorder),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah Alamat Baru',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Input nama penerima alamat.
                          AuthTextField(
                            controller: nameController,
                            hint: 'Nama Penerima',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 12),

                          // Input nomor telepon penerima.
                          AuthTextField(
                            controller: phoneController,
                            hint: 'Nomor HP',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),

                          // Tombol cepat ambil lokasi saat ini via GPS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Alamat Lengkap',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.appTextPrimary,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _isLoadingLocation ? null : _fillCurrentLocation,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: _isLoadingLocation
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.appPrimary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                        color: context.appPrimary,
                                      ),
                                label: Text(
                                  _isLoadingLocation ? 'Mendeteksi...' : 'Lokasi Saat Ini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.appPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Input alamat lengkap dengan beberapa baris teks.
                          AuthTextField(
                            controller: detailController,
                            hint: 'Alamat lengkap (jalan, RT/RW, kota)',
                            icon: Icons.location_on_outlined,
                            maxLines: 3,
                          ),

                          // Menampilkan pesan kesalahan jika validasi gagal.
                          if (errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              errorMessage,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: context.appDanger,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Tombol untuk memvalidasi dan menyimpan alamat.
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: saveAddress,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: context.appPrimary,
                                foregroundColor: onAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_location_alt_outlined,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Simpan Alamat',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Judul bagian yang menampilkan daftar alamat tersimpan.
                    Text(
                      'Alamat Tersimpan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Menampilkan informasi jika belum ada alamat tersimpan.
                    if (provider.addresses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: Text(
                          'Belum ada alamat tersimpan',
                          style: TextStyle(
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),

                    // Membuat kartu untuk setiap alamat yang tersedia.
                    for (final address in provider.addresses) ...[
                      _buildAddressCard(context, provider, address, onAccent),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Membuat kartu alamat yang berisi informasi penerima dan tombol pengelolaan.
  Widget _buildAddressCard(
      BuildContext context,
      AddressProvider provider,
      Address address,
      Color onAccent,
      ) {
    // Memeriksa apakah alamat yang ditampilkan merupakan alamat utama.
    final isMain = provider.mainAddressId == address.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        // Memberikan garis tepi berbeda pada alamat yang ditetapkan sebagai utama.
        border: Border.all(
          color: isMain ? context.appPrimary : context.appBorder,
          width: isMain ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Menampilkan nama penerima dan penanda alamat utama.
          Row(
            children: [
              Expanded(
                child: Text(
                  address.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              if (isMain)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.appPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Utama',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: onAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),

          // Menampilkan nomor telepon penerima.
          Text(
            address.phone,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Menampilkan detail alamat pengiriman.
          Text(
            address.detail,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Menyediakan tombol untuk menetapkan alamat utama dan menghapus alamat.
          Row(
            children: [
              // Tombol penetapan alamat utama hanya tampil pada alamat nonutama.
              if (!isMain)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context
                        .read<AddressProvider>()
                        .setMain(address.id),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: context.appSurfaceLight,
                      foregroundColor: context.appPrimaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Jadikan Utama',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Memberikan jarak jika tombol penetapan alamat utama ditampilkan.
              if (!isMain) const SizedBox(width: 8),

              // Menghapus alamat berdasarkan ID melalui AddressProvider.
              ElevatedButton(
                onPressed: () => context
                    .read<AddressProvider>()
                    .removeAddress(address.id),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: context.appSurfaceLight,
                  foregroundColor: context.appDanger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}