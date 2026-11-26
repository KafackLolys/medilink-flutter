import 'package:flutter/material.dart';

import '../../../core/api/medilink_api.dart';
import '../../auth/application/auth_controller.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF172554);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE5EAF3);
const _canvas = Color(0xFFF5F7FC);

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
  final search = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();

  bool get authorized => widget.auth.role == 'admin' &&
      MedilinkApi.instance.isConfigured &&
      MedilinkApi.instance.isAuthenticated;

  @override
  void initState() {
    super.initState();
    if (authorized) _load();
  }

  @override
  void dispose() {
    for (final controller in [search, first, last, email, password, phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!authorized) return;
    setState(() {
      loading = true;
      error = null;
      notice = null;
    });
    try {
      final result = await MedilinkApi.instance.adminAccounts(
        role: role, page: page, pageSize: 10, q: query,
      );
      if (!mounted) return;
      setState(() {
        accounts = (result['items'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        total = (result['total'] as num?)?.toInt() ?? 0;
        totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
      });
    } catch (exception) {
      if (mounted) setState(() => error = 'Chargement impossible : $exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> account,
      {String? status, bool? emailVerified, String? verificationStatus}) async {
    setState(() {
      error = null;
      notice = null;
    });
    final id = '${account['id']}';
    try {
      if (status != null && status != account['status']) {
        await MedilinkApi.instance.adminUpdateAccountStatus(id, status);
      }
      if (role == 'patient' && emailVerified != null &&
          emailVerified != account['emailVerified']) {
        await MedilinkApi.instance.adminVerification(id: id, emailVerified: emailVerified);
      }
      if (role == 'doctor' && verificationStatus != null &&
          verificationStatus != account['verificationStatus']) {
        await MedilinkApi.instance.adminVerification(id: id, verificationStatus: verificationStatus);
      }
      if (mounted) {
        setState(() => notice = 'Modifications enregistrées.');
        await _load();
      }
    } catch (exception) {
      if (mounted) setState(() => error = 'Échec de la mise à jour : $exception');
    }
  }

  Future<void> _createAdmin() async {
    if (first.text.trim().isEmpty || last.text.trim().isEmpty ||
        email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Renseignez le prénom, le nom, l’e-mail et le mot de passe.');
      return;
    }
    setState(() {
      creating = true;
      error = null;
      notice = null;
    });
    try {
      await MedilinkApi.instance.adminCreateAdmin({
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
      });
      if (!mounted) return;
      first.clear();
      last.clear();
      email.clear();
      password.clear();
      phone.clear();
      setState(() => notice = 'Le compte administrateur a été créé.');
    } catch (exception) {
      if (mounted) setState(() => error = 'Création impossible : $exception');
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!authorized) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 35),
          Icon(Icons.admin_panel_settings_outlined, size: 56, color: _blue),
          SizedBox(height: 14),
          Text('Administration indisponible',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
          SizedBox(height: 8),
          Text('Connectez-vous avec un compte administrateur autorisé par le serveur.',
              textAlign: TextAlign.center, style: TextStyle(color: _muted)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          const Text('Administration',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 5),
          const Text('Gérez les comptes patients et les professionnels de santé.',
              style: TextStyle(color: _muted, height: 1.4)),
          const SizedBox(height: 18),
          _overviewCard(),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Gestion des comptes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink))),
            IconButton(
              tooltip: 'Actualiser',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, color: _blue),
            ),
          ]),
          const SizedBox(height: 10),
          _roleSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              query = value.trim();
              page = 1;
              _load();
            },
            decoration: InputDecoration(
              hintText: 'Nom, e-mail ou téléphone',
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              suffixIcon: IconButton(
                tooltip: 'Effacer',
                onPressed: () {
                  search.clear();
                  query = '';
                  page = 1;
                  _load();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _blue, width: 1.4)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('$total ${role == 'patient' ? 'patients' : 'médecins'}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
            const Spacer(),
            Text('Page $page / ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
          if (loading) const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(minHeight: 3),
          ),
          if (error != null) _message(error!, const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
          if (notice != null) _message(notice!, const Color(0xFFECFDF5), const Color(0xFF047857)),
          const SizedBox(height: 4),
          if (!loading && accounts.isEmpty)
            _emptyState()
          else
            ...accounts.map(_accountCard),
          if (totalPages > 1) _pagination(),
          const SizedBox(height: 24),
          _createAdminSection(),
        ],
      ),
    );
  }

  Widget _overviewCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
    ),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: const Color(0xFFEAF1FF), borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.manage_accounts_rounded, color: _blue, size: 27),
      ),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Comptes de la plateforme', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 3),
        Text('$total ${role == 'patient' ? 'patients affichés dans le résultat' : 'médecins affichés dans le résultat'}',
            style: const TextStyle(fontSize: 12, color: _muted)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
        child: Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _blue)),
      ),
    ]),
  );

  Widget _roleSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: const Color(0xFFE9EEF8), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      _roleButton('patient', 'Patients', Icons.people_alt_outlined),
      _roleButton('doctor', 'Médecins', Icons.medical_services_outlined),
    ]),
  );

  Widget _roleButton(String value, String label, IconData icon) {
    final selected = role == value;
    return Expanded(child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (role == value) return;
        setState(() { role = value; page = 1; });
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [BoxShadow(color: _blue.withOpacity(.16), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: selected ? Colors.white : _muted),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _muted)),
        ]),
      ),
    ));
  }

  Widget _accountCard(Map<String, dynamic> account) {
    final status = '${account['status'] ?? 'pending'}';
    final verification = '${account['verificationStatus'] ?? 'pending'}';
    final name = '${account['firstName'] ?? ''} ${account['lastName'] ?? ''}'.trim();
    final initials = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty)
        .take(2).map((part) => part[0].toUpperCase()).join();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 23, backgroundColor: const Color(0xFFEAF1FF),
              child: Text(initials.isEmpty ? '?' : initials,
                  style: const TextStyle(color: _blue, fontWeight: FontWeight.w800))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? 'Compte sans nom' : name,
                style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 3),
            Text(account['email']?.toString() ?? 'E-mail absent',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _muted)),
            if ((account['phone'] ?? '').toString().isNotEmpty)
              Text(account['phone'].toString(), style: const TextStyle(fontSize: 12, color: _muted)),
          ])),
          _statusChip(status),
        ]),
        const SizedBox(height: 14),
        _dropdown<String>(
          label: 'Statut du compte',
          value: status,
          values: const ['active', 'pending', 'suspended', 'deleted'],
          onChanged: (value) => _save(account, status: value),
        ),
        if (role == 'patient')
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.only(left: 2),
            dense: true,
            activeColor: _blue,
            title: const Text('Adresse e-mail vérifiée', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: account['emailVerified'] == true,
            onChanged: (value) => _save(account, emailVerified: value),
          ),
        if (role == 'doctor')
          _dropdown<String>(
            label: 'Vérification professionnelle',
            value: verification,
            values: const ['pending', 'verified', 'rejected', 'suspended'],
            onChanged: (value) => _save(account, verificationStatus: value),
          ),
      ]),
    );
  }

  Widget _dropdown<T>({required String label, required String value,
      required List<String> values, required ValueChanged<String?> onChanged}) =>
      DropdownButtonFormField<String>(
        value: values.contains(value) ? value : values.first,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFAFBFE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
        ),
        items: values.map((item) => DropdownMenuItem(
          value: item, child: Text(_label(item), style: const TextStyle(fontSize: 13)),
        )).toList(),
        onChanged: onChanged,
      );

  Widget _statusChip(String status) {
    final color = switch (status) {
      'active' => const Color(0xFF15803D),
      'pending' => const Color(0xFFB45309),
      'suspended' || 'deleted' => const Color(0xFFB91C1C),
      _ => _muted,
    };
    final background = switch (status) {
      'active' => const Color(0xFFDCFCE7),
      'pending' => const Color(0xFFFFF7ED),
      'suspended' || 'deleted' => const Color(0xFFFEE2E2),
      _ => const Color(0xFFF1F5F9),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(_label(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _pagination() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton.filledTonal(
        onPressed: page > 1 && !loading ? () { setState(() => page--); _load(); } : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('$page / $totalPages', style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
      ),
      IconButton.filledTonal(
        onPressed: page < totalPages && !loading ? () { setState(() => page++); _load(); } : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ]),
  );

  Widget _createAdminSection() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFFEAF1FF), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_add_alt_1_rounded, color: _blue)),
        const SizedBox(width: 11),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Créer un administrateur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          Text('Ajouter un compte avec les droits administrateur.', style: TextStyle(fontSize: 12, color: _muted)),
        ])),
      ]),
      const SizedBox(height: 16),
      _createField(first, 'Prénom'),
      _createField(last, 'Nom'),
      _createField(email, 'Adresse e-mail', keyboardType: TextInputType.emailAddress),
      _createField(phone, 'Téléphone (facultatif)', keyboardType: TextInputType.phone),
      _createField(password, 'Mot de passe', secret: true),
      const SizedBox(height: 5),
      SizedBox(width: double.infinity, height: 50,
        child: FilledButton.icon(
          onPressed: creating ? null : _createAdmin,
          icon: creating
              ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.person_add_alt_1_rounded),
          label: Text(creating ? 'Création…' : 'Créer le compte'),
          style: FilledButton.styleFrom(backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
    ]),
  );

  Widget _createField(TextEditingController controller, String label,
      {bool secret = false, TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextField(
      controller: controller,
      obscureText: secret,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFAFBFE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _border)),
      ),
    ),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
    child: const Column(children: [
      Icon(Icons.person_search_outlined, size: 38, color: _muted),
      SizedBox(height: 9),
      Text('Aucun compte trouvé', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
      SizedBox(height: 4),
      Text('Modifiez votre recherche ou changez de catégorie.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _muted)),
    ]),
  );

  Widget _message(String text, Color background, Color foreground) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: TextStyle(color: foreground)),
  );

  static String _label(String value) => switch (value) {
    'active' => 'Actif',
    'pending' => 'En attente',
    'suspended' => 'Suspendu',
    'deleted' => 'Supprimé',
    'verified' => 'Vérifié',
    'rejected' => 'Refusé',
    _ => value,
  };
}
