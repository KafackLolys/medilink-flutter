import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/data/live_state.dart';
import '../../../core/widgets/medilink_logo_mark.dart';

import '../application/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Compte créé. Confirmez votre e-mail avant de vous connecter.')));
      }
    } else {
      final emailValue = email.text.trim();
      final passwordValue = password.text;
      if (emailValue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saisissez votre e-mail.')),
        );
        return;
      }
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail invalide.')),
        );
        return;
      }
      if (passwordValue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saisissez votre mot de passe.')),
        );
        return;
      }
      await widget.auth.login(emailValue, passwordValue);
    }
    if (mounted && widget.auth.error != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.auth.error!)));
  }

  Future<void> _signInWithGoogle() async {
    await widget.auth.signInWithGoogle(role);
    if (mounted && widget.auth.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.auth.error!)));
    }
  }

  Future<void> _resetPassword() async {
    final emailValue = email.text.trim();
    if (emailValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez votre e-mail.')),
      );
      return;
    }
    await widget.auth.resetPassword(emailValue);
    if (mounted && widget.auth.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.auth.error!)));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Si ce compte existe, un e-mail a été envoyé.')),
      );
    }
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
                    const MedilinkLogoMark(),
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
                    Text(
                      widget.auth.usesApi
                          ? 'Connectez-vous avec votre compte MedLink'
                          : 'Connexion indisponible · configurez API_BASE_URL',
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
                            prefixIcon:
                                Icon(LineAwesomeIcons.stethoscope_solid),
                          ),
                          hint: const Text('Sélectionner une spécialité'),
                          items: LiveState.specialties
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
                        prefixIcon: Icon(LineAwesomeIcons.envelope_solid),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(LineAwesomeIcons.lock_solid),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.auth.busy ? null : _resetPassword,
                        child: const Text('Mot de passe oublié ?'),
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
                    const SizedBox(height: 24),
                    // Authentification Google temporairement masquée.
                    // Le contrôleur et la méthode Google restent disponibles
                    // pour une réactivation ultérieure.
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Icône Google locale (sans dépendance réseau) pour le bouton d'authentification.
class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xff4285f4),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
