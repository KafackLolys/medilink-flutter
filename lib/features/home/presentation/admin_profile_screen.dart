import 'package:flutter/material.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';

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
  bool saving = false;
  String? error, notice;
  @override
  void dispose() {
    first.dispose();
    last.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('Mon profil',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text(
            'Mettez à jour vos coordonnées. Les droits administrateur restent inchangés.'),
        const SizedBox(height: 18),
        if (!MedilinkApi.instance.isConfigured)
          const Text(
              'Configurez l’API et connectez-vous avec un compte administrateur réel pour enregistrer ce profil.'),
        _field(first, 'Prénom'),
        _field(last, 'Nom'),
        _field(phone, 'Téléphone'),
        TextFormField(
            initialValue: '${widget.auth.user?['email'] ?? ''}',
            readOnly: true,
            decoration:
                const InputDecoration(labelText: 'E-mail (non modifiable)')),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (notice != null)
          Text(notice!, style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 12),
        FilledButton(
            onPressed:
                saving || !MedilinkApi.instance.isConfigured ? null : _save,
            child: Text(
                saving ? 'Enregistrement…' : 'Enregistrer les modifications'))
      ]);
  Widget _field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
          controller: c,
          maxLength: label == 'Téléphone' ? 30 : 80,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder())));
  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final result = await MedilinkApi.instance.adminUpdateProfile(
          firstName: first.text.trim(),
          lastName: last.text.trim(),
          phone: phone.text.trim());
      final user = result['user'];
      if (user is Map) {
        widget.auth.updateUserProfile(Map<String, dynamic>.from(user));
      }
      if (mounted) setState(() => notice = 'Profil mis à jour par le serveur.');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
