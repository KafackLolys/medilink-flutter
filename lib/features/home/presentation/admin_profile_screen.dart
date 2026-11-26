import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../../../core/api/medilink_api.dart';
import '../../auth/application/auth_controller.dart';

const _adminBlue = Color(0xFF2563EB);
const _adminInk = Color(0xFF172554);
const _adminMuted = Color(0xFF64748B);
const _adminBorder = Color(0xFFE5EAF3);

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final first =
      TextEditingController(text: '${widget.auth.user?['firstName'] ?? ''}');
  late final last =
      TextEditingController(text: '${widget.auth.user?['lastName'] ?? ''}');
  late final phone =
      TextEditingController(text: '${widget.auth.user?['phone'] ?? ''}');
  String? photoUrl;
  bool saving = false;
  bool uploadingPhoto = false;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    photoUrl = widget.auth.user?['photoUrl']?.toString();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    if (!MedilinkApi.instance.isConfigured) return;
    try {
      final result = await MedilinkApi.instance.adminProfilePhoto();
      final url = result['photoUrl']?.toString();
      if (!mounted) return;
      setState(() => photoUrl = url?.isNotEmpty == true ? url : null);
      if (url != null && url.isNotEmpty) {
        await widget.auth.updateUserProfile({'photoUrl': url});
      }
    } catch (_) {
      // L'écran reste utilisable même si le lien de photo ne peut être actualisé.
    }
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty || !mounted) return;
    final selected = selection.files.single;
    final source = selected.bytes;
    if (source == null) {
      _showMessage('Impossible de lire cette image.');
      return;
    }
    if (source.length > 8 * 1024 * 1024) {
      _showMessage('Choisissez une image de 8 Mo maximum avant compression.');
      return;
    }

    setState(() {
      uploadingPhoto = true;
      error = null;
      notice = null;
    });
    try {
      final decoded = img.decodeImage(source);
      if (decoded == null) {
        throw const FormatException('Le fichier sélectionné n’est pas une image valide.');
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width > 720 ? 720 : decoded.width,
        height: decoded.height > 720 ? 720 : decoded.height,
        maintainAspect: true,
        interpolation: img.Interpolation.average,
      );
      final compressed = img.encodeJpg(resized, quality: 78);
      if (compressed.length > 2 * 1024 * 1024) {
        throw const FormatException(
          'La photo reste trop volumineuse après compression. Choisissez une autre image.',
        );
      }

      final result = await MedilinkApi.instance.adminUploadProfilePhoto(
        file: http.MultipartFile.fromBytes(
          'file',
          compressed,
          filename: 'admin-profile.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      final url = result['photoUrl']?.toString();
      if (url == null || url.isEmpty) {
        throw const FormatException('Le serveur n’a pas retourné la photo.');
      }
      if (!mounted) return;
      setState(() {
        photoUrl = url;
        notice = 'Photo de profil mise à jour.';
      });
      await widget.auth.updateUserProfile({'photoUrl': url});
    } catch (exception) {
      if (mounted) setState(() => error = 'Import de la photo impossible : $exception');
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user ?? const <String, dynamic>{};
    final fullName = '${first.text} ${last.text}'.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        const Text('Mon profil',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _adminInk)),
        const SizedBox(height: 5),
        const Text('Gérez vos informations personnelles et votre photo.',
            style: TextStyle(color: _adminMuted, height: 1.4)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _adminBorder),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFEAF1FF),
                    backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                        ? NetworkImage(photoUrl!)
                        : null,
                    child: photoUrl == null || photoUrl!.isEmpty
                        ? const Icon(Icons.person_rounded, size: 48, color: _adminBlue)
                        : null,
                  ),
                  Material(
                    color: _adminBlue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: uploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: uploadingPhoto
                            ? const SizedBox(
                                width: 17, height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_outlined,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(fullName.isEmpty ? 'Administrateur' : fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: _adminInk)),
              const SizedBox(height: 4),
              const Text('Administrateur MediLink',
                  style: TextStyle(color: _adminMuted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: uploadingPhoto ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                label: Text(uploadingPhoto ? 'Compression et import…' : 'Changer la photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _adminBlue,
                  side: const BorderSide(color: Color(0xFFBFCEFA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ),
              const SizedBox(height: 4),
              const Text('JPEG, PNG ou WEBP · compression automatique · 2 Mo maximum après compression',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _adminMuted)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _formCard(
          title: 'Informations personnelles',
          subtitle: 'Ces informations sont associées à votre compte administrateur.',
          children: [
            _field(first, 'Prénom', Icons.person_outline_rounded),
            _field(last, 'Nom', Icons.badge_outlined),
            _field(phone, 'Téléphone', Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            _readonlyField(user['email']?.toString() ?? '', 'Adresse e-mail',
                Icons.mail_outline_rounded),
          ],
        ),
        if (error != null) _message(error!, const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
        if (notice != null) _message(notice!, const Color(0xFFECFDF5), const Color(0xFF047857)),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: saving || !MedilinkApi.instance.isConfigured ? null : _save,
            icon: saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Enregistrement…' : 'Enregistrer les modifications'),
            style: FilledButton.styleFrom(
              backgroundColor: _adminBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _formCard({required String title, required String subtitle, required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _adminBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _adminInk)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _adminMuted)),
          const SizedBox(height: 18),
          ...children,
        ]),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {TextInputType? keyboardType}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: label == 'Téléphone' ? 30 : 80,
          decoration: _decoration(label, icon),
        ),
      );

  Widget _readonlyField(String value, String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TextField(
          controller: TextEditingController(text: value),
          readOnly: true,
          decoration: _decoration(label, icon).copyWith(
            filled: true,
            fillColor: const Color(0xFFF5F7FB),
            helperText: 'Non modifiable',
          ),
        ),
      );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _adminMuted, size: 20),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFFAFBFE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _adminBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _adminBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _adminBlue, width: 1.4)),
      );

  Widget _message(String text, Color background, Color foreground) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: foreground)),
      );

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
      notice = null;
    });
    try {
      final result = await MedilinkApi.instance.adminUpdateProfile(
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        phone: phone.text.trim(),
      );
      final updatedUser = result['user'];
      if (updatedUser is Map) {
        widget.auth.updateUserProfile(Map<String, dynamic>.from(updatedUser));
      }
      if (mounted) setState(() => notice = 'Profil mis à jour.');
    } catch (exception) {
      if (mounted) setState(() => error = 'Enregistrement impossible : $exception');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
