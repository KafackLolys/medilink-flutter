import 'package:flutter/material.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  String role = 'patient', query = '';
  int page = 1, total = 0, totalPages = 0;
  bool loading = false, creating = false;
  String? error, notice;
  List<Map<String, dynamic>> accounts = [];
  final search = TextEditingController(),
      first = TextEditingController(),
      last = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      phone = TextEditingController();
  bool get authorized =>
      widget.auth.role == 'admin' &&
      MedilinkApi.instance.isConfigured &&
      MedilinkApi.instance.isAuthenticated;
  @override
  void initState() {
    super.initState();
    if (authorized) _load();
  }

  @override
  void dispose() {
    for (final c in [search, first, last, email, password, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!authorized) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await MedilinkApi.instance
          .adminAccounts(role: role, page: page, pageSize: 10, q: query);
      if (!mounted) return;
      setState(() {
        accounts = (r['items'] as List? ?? [])
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
            .toList();
        total = (r['total'] as num?)?.toInt() ?? 0;
        totalPages = (r['totalPages'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> a,
      {String? status, bool? emailVerified, String? verificationStatus}) async {
    setState(() => error = null);
    final id = '${a['id']}';
    try {
      if (status != null && status != a['status'])
        await MedilinkApi.instance.adminUpdateAccountStatus(id, status);
      if (role == 'patient' &&
          emailVerified != null &&
          emailVerified != a['emailVerified'])
        await MedilinkApi.instance
            .adminVerification(id: id, emailVerified: emailVerified);
      if (role == 'doctor' &&
          verificationStatus != null &&
          verificationStatus != a['verificationStatus'])
        await MedilinkApi.instance
            .adminVerification(id: id, verificationStatus: verificationStatus);
      if (mounted) {
        setState(() => notice = 'Modifications enregistrées par le serveur.');
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Échec de la mise à jour : $e');
    }
  }

  Future<void> _createAdmin() async {
    setState(() => creating = true);
    try {
      await MedilinkApi.instance.adminCreateAdmin({
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim()
      });
      if (!mounted) return;
      first.clear();
      last.clear();
      email.clear();
      password.clear();
      phone.clear();
      setState(
          () => notice = 'Le compte administrateur a été créé sur le serveur.');
    } catch (e) {
      if (mounted) setState(() => error = 'Création impossible : $e');
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!authorized) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text('Administration',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        const Icon(Icons.admin_panel_settings_outlined,
            size: 52, color: AppTheme.primary),
        const SizedBox(height: 12),
        const Text(
            'Accès administrateur indisponible. Connectez-vous avec un compte administrateur autorisé par le serveur.',
            textAlign: TextAlign.center),
      ]);
    }
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Text('Comptes de la plateforme',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          Text('$total ${role == 'patient' ? 'patients' : 'médecins'}'),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (notice != null)
            Text(notice!, style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Type de compte'),
              items: const [
                DropdownMenuItem(value: 'patient', child: Text('Patients')),
                DropdownMenuItem(value: 'doctor', child: Text('Médecins'))
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    role = v;
                    page = 1;
                  });
                  _load();
                }
              }),
          TextField(
              controller: search,
              decoration: const InputDecoration(
                  labelText: 'Nom, e-mail ou téléphone',
                  prefixIcon: Icon(Icons.search)),
              onSubmitted: (v) {
                query = v.trim();
                page = 1;
                _load();
              }),
          if (loading) const LinearProgressIndicator(),
          ...accounts.map(_account),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: page > 1
                    ? () {
                        setState(() => page--);
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left)),
            Text('$page / ${totalPages == 0 ? 1 : totalPages}'),
            IconButton(
                onPressed: page < totalPages
                    ? () {
                        setState(() => page++);
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right))
          ]),
          const SizedBox(height: 16),
          _section('Créer un administrateur', [
            _field(first, 'Prénom'),
            _field(last, 'Nom'),
            _field(email, 'E-mail'),
            _field(phone, 'Téléphone (facultatif)'),
            _field(password, 'Mot de passe', secret: true),
            FilledButton(
                onPressed: creating ? null : _createAdmin,
                child: Text(creating ? 'Création…' : 'Créer le compte'))
          ]),
        ]));
  }

  Widget _account(Map<String, dynamic> a) {
    final status = '${a['status'] ?? 'pending'}',
        verified = '${a['verificationStatus'] ?? 'pending'}';
    return Card(
        margin: const EdgeInsets.only(top: 10),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${a['email'] ?? ''} · ${a['phone'] ?? 'Téléphone absent'}'),
              DropdownButtonFormField<String>(
                  value: status,
                  decoration:
                      const InputDecoration(labelText: 'Statut du compte'),
                  items: const ['active', 'pending', 'suspended', 'deleted']
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text(_label(v))))
                      .toList(),
                  onChanged: (v) => _save(a, status: v)),
              if (role == 'patient')
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('E-mail vérifié'),
                    value: a['emailVerified'] == true,
                    onChanged: (v) => _save(a, emailVerified: v)),
              if (role == 'doctor')
                DropdownButtonFormField<String>(
                    value: verified,
                    decoration: const InputDecoration(
                        labelText: 'Vérification professionnelle'),
                    items: const [
                      'pending',
                      'verified',
                      'rejected',
                      'suspended'
                    ]
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text(_label(v))))
                        .toList(),
                    onChanged: (v) => _save(a, verificationStatus: v))
            ])));
  }

  Widget _section(String title, List<Widget> children) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 12),
            ...children
          ])));
  Widget _field(TextEditingController c, String label, {bool secret = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: c,
              obscureText: secret,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder())));
  static String _label(String v) => switch (v) {
        'active' => 'Actif',
        'pending' => 'En attente',
        'suspended' => 'Suspendu',
        'deleted' => 'Supprimé',
        'verified' => 'Vérifié',
        'rejected' => 'Refusé',
        _ => v
      };
}
