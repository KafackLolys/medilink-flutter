import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/theme/app_theme.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  static const bloodTypes = <String, String>{
    'unknown': 'Inconnu',
    'a_positive': 'A+',
    'a_negative': 'A−',
    'b_positive': 'B+',
    'b_negative': 'B−',
    'ab_positive': 'AB+',
    'ab_negative': 'AB−',
    'o_positive': 'O+',
    'o_negative': 'O−',
  };
  static const documentTypes = <String, String>{
    'prescription': 'Ordonnance',
    'lab_result': 'Résultat d’analyse',
    'medical_report': 'Compte rendu médical',
    'imaging': 'Imagerie',
    'identity_document': 'Pièce d’identité',
    'other': 'Autre document',
  };

  Map<String, dynamic> profile = {};
  List<Map<String, dynamic>> conditions = [];
  List<Map<String, dynamic>> documents = [];
  final name = TextEditingController();
  final phone = TextEditingController();
  final city = TextEditingController();
  final district = TextEditingController();
  final documentTitle = TextEditingController();
  String section = 'profil';
  String bloodType = 'unknown';
  String documentType = 'lab_result';
  bool loading = true;
  bool editing = false;
  bool saving = false;
  bool uploading = false;
  String? error;

  bool get apiMode => MedilinkApi.instance.isConfigured;
  bool get hasRegisteredAddress =>
      profile['patient'] is Map && profile['patient']['address'] is Map;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    city.dispose();
    district.dispose();
    documentTitle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (apiMode) {
        final values = await Future.wait<dynamic>([
          MedilinkApi.instance.profile(),
          MedilinkApi.instance.patientConditions(),
          MedilinkApi.instance.patientDocuments(),
        ]);
        profile = Map<String, dynamic>.from(values[0] as Map);
        conditions = values[1] as List<Map<String, dynamic>>;
        documents = values[2] as List<Map<String, dynamic>>;
      } else {
        throw const MedilinkApiException('API_BASE_URL n’est pas configurée.');
      }
      _populateFields();
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _populateFields() {
    final patient = Map<String, dynamic>.from(profile['patient'] as Map? ?? {});
    final user =
        Map<String, dynamic>.from(profile['user'] as Map? ?? widget.user);
    name.text = patient['fullName']?.toString() ??
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    phone.text = user['phone']?.toString() ?? '';
    final address = Map<String, dynamic>.from(patient['address'] as Map? ?? {});
    city.text = address['city']?.toString() ?? '';
    district.text = address['district']?.toString() ?? '';
    bloodType = bloodTypes.containsKey(patient['bloodType']?.toString())
        ? patient['bloodType'].toString()
        : 'unknown';
  }

  Future<void> _saveProfile() async {
    if (name.text.trim().length < 2 ||
        phone.text.trim().length < 6 ||
        (hasRegisteredAddress &&
            (city.text.trim().isEmpty || district.text.trim().isEmpty))) {
      _toast(
          'Complétez les informations personnelles et l’adresse déjà enregistrée.');
      return;
    }
    setState(() => saving = true);
    try {
      final fullName = name.text.trim();
      if (!apiMode) {
        throw const MedilinkApiException('API_BASE_URL n’est pas configurée.');
      }
      await MedilinkApi.instance.patientSaveProfile(
          name: fullName,
          phone: phone.text.trim(),
          bloodType: bloodType,
          city: hasRegisteredAddress ? city.text.trim() : '',
          district: hasRegisteredAddress ? district.text.trim() : '',
        );
      final user = Map<String, dynamic>.from(profile['user'] as Map);
      final patient = Map<String, dynamic>.from(profile['patient'] as Map);
      final parts = fullName.split(RegExp(r'\s+'));
      user['firstName'] = parts.first;
      user['lastName'] = parts.skip(1).join(' ');
      user['phone'] = phone.text.trim();
      patient['fullName'] = fullName;
      patient['bloodType'] = bloodType;
      patient['address'] = hasRegisteredAddress
          ? {'city': city.text.trim(), 'district': district.text.trim()}
          : null;
      profile = {...profile, 'user': user, 'patient': patient};
      if (mounted) setState(() => editing = false);
      _toast('Profil enregistré.');
    } catch (exception) {
      _toast('Enregistrement impossible : $exception');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _uploadDocument() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty || !mounted) return;
    final file = selection.files.single;
    final bytes = file.bytes;
    const mimeTypes = <String, String>{
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final mime = mimeTypes[(file.extension ?? '').toLowerCase()];
    if (bytes == null || mime == null) {
      _toast('Formats acceptés : PDF, JPEG, PNG ou WEBP.');
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      _toast('Le document ne doit pas dépasser 10 Mo.');
      return;
    }
    setState(() => uploading = true);
    try {
      if (apiMode) {
        documents.insert(
            0,
            await MedilinkApi.instance.patientUploadDocument(
              type: documentType,
              title: documentTitle.text.trim().isEmpty
                  ? null
                  : documentTitle.text.trim(),
              file: http.MultipartFile.fromBytes('file', bytes,
                  filename: file.name, contentType: MediaType.parse(mime)),
            ));
      } else {
        throw const MedilinkApiException('API_BASE_URL n’est pas configurée.');
      }
      documentTitle.clear();
      if (mounted) setState(() {});
      _toast('Document ajouté au dossier médical.');
    } catch (exception) {
      _toast('Import impossible : $exception');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Supprimer ce document ?'),
              content: Text(
                  '« ${item['title'] ?? 'Document médical'} » sera retiré du dossier.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Garder')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Supprimer')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    try {
      await MedilinkApi.instance.patientDeleteDocument(item['id'].toString());
      setState(() => documents.removeWhere((row) => row['id'] == item['id']));
      _toast('Document supprimé.');
    } catch (exception) {
      _toast('Suppression impossible : $exception');
    }
  }

  Future<void> _openDocument(Map<String, dynamic> item) async {
    final url = item['downloadUrl']?.toString();
    if (url == null || url.isEmpty) {
      _toast('Ce document ne contient pas de lien de téléchargement.');
      return;
    }
    final opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) _toast('Impossible d’ouvrir ce document.');
  }

  void _toast(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final patient = Map<String, dynamic>.from(profile['patient'] as Map? ?? {});
    final user =
        Map<String, dynamic>.from(profile['user'] as Map? ?? widget.user);
    final fullName = patient['fullName']?.toString() ?? 'Patient';
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil et dossier'), actions: [
        IconButton(
            tooltip: 'Actualiser',
            onPressed: loading ? null : _load,
            icon: const Icon(LineAwesomeIcons.sync_solid)),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _errorPanel()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  children: [
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(children: [
                                CircleAvatar(
                                    radius: 28,
                                    child: Text(_initials(fullName))),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(fullName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800)),
                                      Text(user['email']?.toString() ?? '',
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary)),
                                    ])),
                                if (patient['verified'] == true)
                                  const Icon(Icons.verified,
                                      color: AppTheme.primary),
                              ]))),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'profil',
                              label: Text('Profil'),
                              icon: Icon(Icons.person_outline)),
                          ButtonSegment(
                              value: 'dossier',
                              label: Text('Dossier'),
                              icon: Icon(Icons.favorite_border)),
                          ButtonSegment(
                              value: 'documents',
                              label: Text('Documents'),
                              icon: Icon(Icons.folder_open_outlined)),
                        ],
                        selected: {section},
                        onSelectionChanged: (values) =>
                            setState(() => section = values.first),
                      ),
                      const SizedBox(height: 14),
                      if (section == 'profil')
                        _profileSection(user, patient)
                      else if (section == 'dossier')
                        _conditionsSection()
                      else
                        _documentsSection(),
                    ]),
    );
  }

  Widget _profileSection(
          Map<String, dynamic> user, Map<String, dynamic> patient) =>
      Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('Informations personnelles',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                TextButton.icon(
                    onPressed: () {
                      if (!editing) _populateFields();
                      setState(() => editing = !editing);
                    },
                    icon: Icon(editing ? Icons.close : Icons.edit_outlined),
                    label: Text(editing ? 'Annuler' : 'Modifier'))
              ]),
              if (editing) ...[
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Nom complet')),
                const SizedBox(height: 10),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                    value: bloodType,
                    decoration:
                        const InputDecoration(labelText: 'Groupe sanguin'),
                    items: bloodTypes.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => bloodType = v ?? bloodType)),
                const SizedBox(height: 10),
                TextField(
                    controller: city,
                    enabled: hasRegisteredAddress,
                    decoration: const InputDecoration(labelText: 'Ville')),
                const SizedBox(height: 10),
                TextField(
                    controller: district,
                    enabled: hasRegisteredAddress,
                    decoration: const InputDecoration(labelText: 'Quartier')),
                if (!hasRegisteredAddress)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Aucune adresse n’est associée au compte. L’API actuelle permet de modifier une adresse existante.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: saving ? null : _saveProfile,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('Enregistrer'))),
              ] else ...[
                _infoRow(
                    'Téléphone', user['phone']?.toString() ?? 'Non renseigné'),
                _infoRow(
                    'E-mail', user['email']?.toString() ?? 'Non renseigné'),
                _infoRow('Groupe sanguin',
                    bloodTypes[patient['bloodType']] ?? 'Inconnu'),
                _infoRow(
                    'Ville',
                    patient['address'] is Map
                        ? patient['address']['city']?.toString() ??
                            'Non renseignée'
                        : 'Non renseignée'),
                _infoRow(
                    'Quartier',
                    patient['address'] is Map
                        ? patient['address']['district']?.toString() ??
                            'Non renseigné'
                        : 'Non renseigné'),
                _infoRow('Date de naissance',
                    _date(patient['dateOfBirth']?.toString())),
                _infoRow('Genre', _gender(patient['gender']?.toString())),
              ],
            ])),
      );

  Widget _conditionsSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Conditions médicales',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Informations enregistrées dans votre dossier patient.'),
        const SizedBox(height: 12),
        if (conditions.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(
                      child: Text('Aucune condition médicale renseignée.'))))
        else
          ...conditions.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(LineAwesomeIcons.heartbeat_solid)),
                title: Text(item['name']?.toString() ?? 'Condition médicale',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([
                  if ((item['description'] ?? '').toString().isNotEmpty)
                    item['description'].toString(),
                  if ((item['notes'] ?? '').toString().isNotEmpty)
                    item['notes'].toString(),
                  'Diagnostic : ${_date(item['diagnosedAt']?.toString())}',
                ].join('\n')),
                isThreeLine: true,
                trailing:
                    Chip(label: Text(item['status']?.toString() ?? 'active')),
              ))),
        const SizedBox(height: 8),
        const Text(
            'Les conditions sont consultables ici. Contactez votre professionnel de santé pour toute mise à jour.',
            style: TextStyle(color: AppTheme.textSecondary)),
      ]);

  Widget _documentsSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Documents médicaux',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('PDF, JPEG, PNG ou WEBP · taille maximale 10 Mo.'),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                          value: documentType,
                          decoration: const InputDecoration(
                              labelText: 'Type de document'),
                          items: documentTypes.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => documentType = v ?? documentType)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: documentTitle,
                          decoration: const InputDecoration(
                              labelText: 'Titre (facultatif)')),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          onPressed: uploading ? null : _uploadDocument,
                          icon: uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file),
                          label: Text(uploading
                              ? 'Import en cours…'
                              : 'Choisir un document')),
                    ]))),
        const SizedBox(height: 12),
        if (documents.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(
                      child: Text('Aucun document dans votre dossier.'))))
        else
          ...documents.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.description_outlined)),
                title: Text(
                    item['title']?.toString() ??
                        item['filename']?.toString() ??
                        'Document',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${documentTypes[item['type']] ?? 'Autre document'} · ${_size(item['sizeBytes'])} · ${_date(item['uploadedAt']?.toString())}'),
                trailing: PopupMenuButton<String>(
                    onSelected: (action) => action == 'open'
                        ? _openDocument(item)
                        : _deleteDocument(item),
                    itemBuilder: (_) => const [
                          PopupMenuItem(value: 'open', child: Text('Ouvrir')),
                          PopupMenuItem(
                              value: 'delete', child: Text('Supprimer'))
                        ]),
                onTap: () => _openDocument(item),
              ))),
      ]);

  Widget _errorPanel() => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AppTheme.textSecondary),
            const SizedBox(height: 10),
            Text(
                apiMode
                    ? 'Dossier patient indisponible'
                    : 'Profil indisponible',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(error ?? 'Une erreur est survenue.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer')),
          ])));

  Widget _infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 145,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]));

  String _initials(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
  String _date(String? value) {
    final d = DateTime.tryParse(value ?? '');
    return d == null
        ? 'Non renseignée'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _size(dynamic value) {
    final n = (value as num?)?.toInt() ?? 0;
    return n >= 1048576
        ? '${(n / 1048576).toStringAsFixed(1)} Mo'
        : n >= 1024
            ? '${(n / 1024).round()} Ko'
            : '$n o';
  }

  String _gender(String? value) => switch (value) {
        'female' => 'Femme',
        'male' => 'Homme',
        'non_binary' => 'Non binaire',
        _ => 'Non renseigné'
      };
}
