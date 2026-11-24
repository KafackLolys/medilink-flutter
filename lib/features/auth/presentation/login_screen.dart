import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/data/demo_data.dart';

import '../application/demo_session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final DemoSessionController auth;
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      first = TextEditingController(),
      last = TextEditingController(),
      phone = TextEditingController(),
      license = TextEditingController();
  String? selectedSpecialty;
  bool registering = false;
  String role = 'patient';
  Future<void> submit() async {
    if (registering) {
      final data = <String, dynamic>{
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'role': role,
      };
      if (role == 'doctor') {
        if (selectedSpecialty == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Choisissez une spécialité.')),
          );
          return;
        }
        data['specialty'] = selectedSpecialty;
        data['registrationNumber'] = license.text.trim();
      }
      await widget.auth.register(data);
      if (mounted && widget.auth.error == null) {
        setState(() => registering = false);
        final message = widget.auth.usesApi
            ? 'Compte créé. Confirmez votre e-mail avant de vous connecter.'
            : 'Compte créé. Connectez-vous.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } else {
      await widget.auth.login(email.text, password.text);
    }
    if (mounted && widget.auth.error != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.auth.error!)));
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    first.dispose();
    last.dispose();
    phone.dispose();
    license.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      child: const Icon(
                        LucideIcons.heartPulse,
                        size: 34,
                        color: const Colors(0xff29b6a6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MedLink',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xff17324d),
                                letterSpacing: -.5,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      registering
                          ? 'Créer un compte'
                          : 'La santé, plus proche de vous',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff66788a),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mode démonstration · données locales uniquement',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff66788a), fontSize: 12),
                    ),
                    const SizedBox(height: 28),
                    if (registering) ...[
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Type de compte',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'patient',
                            child: Text('Patient'),
                          ),
                          DropdownMenuItem(
                              value: 'doctor', child: Text('Médecin')),
                        ],
                        onChanged: (v) => setState(() {
                          role = v ?? 'patient';
                          selectedSpecialty = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: first,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: last,
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'Téléphone'),
                      ),
                      if (role == 'doctor') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedSpecialty,
                          decoration: const InputDecoration(
                            labelText: 'Spécialité',
                            prefixIcon: Icon(LucideIcons.stethoscope),
                          ),
                          hint: const Text('Sélectionner une spécialité'),
                          items: DemoData.specialties
                              .map(
                                (specialty) => DropdownMenuItem<String>(
                                  value: specialty,
                                  child: Text(specialty),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            selectedSpecialty = value;
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: license,
                          decoration: const InputDecoration(
                            labelText: 'Numéro professionnel',
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                        prefixIcon: Icon(LucideIcons.mail),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(LucideIcons.lockKeyhole),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.auth.busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: widget.auth.busy
                            ? const CircularProgressIndicator()
                            : Text(
                                registering
                                    ? 'Créer mon compte'
                                    : 'Se connecter',
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => registering = !registering),
                      child: Text(
                        registering
                            ? 'Déjà inscrit ? Se connecter'
                            : 'Créer un compte',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
