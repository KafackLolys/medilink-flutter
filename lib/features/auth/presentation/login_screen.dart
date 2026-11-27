import 'package:flutter/foundation.dart';
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
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          primaryColor: const Color(0xff2563eb),
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xff2563eb),
            secondary: const Color(0xff0d9488),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xfff5f8ff),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xfff8faff),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            labelStyle: const TextStyle(color: Color(0xff64748b)),
            prefixIconColor: const Color(0xff64748b),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xff2563eb), width: 1.6),
            ),
          ),
        ),
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: _AuthSoftBackground()),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.92),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x142563eb), blurRadius: 28, offset: Offset(0, 10)),
                                ],
                              ),
                              child: const MedilinkLogoMark(size: 54),
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Text('MediLink', textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xff172554), fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                          const SizedBox(height: 7),
                          Text(registering ? 'Rejoignez une communauté de santé plus proche' : 'La santé, plus proche de vous',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xff64748b), fontSize: 14, height: 1.5)),
                          const SizedBox(height: 25),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.96),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: const Color(0xffe7edf7)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x10213b70), blurRadius: 32, offset: Offset(0, 14)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(registering ? 'Créer un compte' : 'Bienvenue',
                                  style: const TextStyle(color: Color(0xff172554), fontSize: 23, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                Text(
                                  !widget.auth.usesApi
                                    ? 'Connexion indisponible — configurez API_BASE_URL'
                                    : registering ? 'Renseignez vos informations pour commencer.' : 'Connectez-vous pour accéder à votre espace.',
                                  style: const TextStyle(color: Color(0xff64748b), fontSize: 13, height: 1.45)),
                                const SizedBox(height: 22),
                                if (registering) ...[
                                  DropdownButtonFormField<String>(
                                    value: role,
                                    decoration: const InputDecoration(labelText: 'Type de compte', prefixIcon: Icon(Icons.people_outline)),
                                    items: const [
                                      DropdownMenuItem(value: 'patient', child: Text('Patient')),
                                      DropdownMenuItem(value: 'doctor', child: Text('Médecin')),
                                    ],
                                    onChanged: (v) => setState(() { role = v ?? 'patient'; selectedSpecialty = null; }),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(controller: first, textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person_outline))),
                                  const SizedBox(height: 12),
                                  TextField(controller: last, textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.badge_outlined))),
                                  const SizedBox(height: 12),
                                  TextField(controller: phone, keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined))),
                                  if (role == 'doctor') ...[
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: selectedSpecialty,
                                      decoration: const InputDecoration(labelText: 'Spécialité', prefixIcon: Icon(Icons.medical_services_outlined)),
                                      hint: const Text('Sélectionner une spécialité'),
                                      items: LiveState.specialties.map((specialty) => DropdownMenuItem<String>(value: specialty, child: Text(specialty))).toList(),
                                      onChanged: (value) => setState(() => selectedSpecialty = value),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(controller: license,
                                      decoration: const InputDecoration(labelText: 'Numéro professionnel', prefixIcon: Icon(Icons.assignment_ind_outlined))),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                                TextField(controller: email, keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.email_outlined))),
                                const SizedBox(height: 12),
                                TextField(controller: password, obscureText: true,
                                  autofillHints: [registering ? AutofillHints.newPassword : AutofillHints.password],
                                  decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline))),
                                if (!registering)
                                  Align(alignment: Alignment.centerRight,
                                    child: TextButton(onPressed: widget.auth.busy ? null : _resetPassword, child: const Text('Mot de passe oublié ?')))
                                else
                                  const SizedBox(height: 18),
                                const SizedBox(height: 5),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xff2563eb), foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                                    onPressed: widget.auth.busy ? null : submit,
                                    child: widget.auth.busy
                                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Text(registering ? 'Créer mon compte' : 'Se connecter',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, size: 19),
                                        ]),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (!kIsWeb) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider(color: Color(0xffe2e8f0))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'OU',
                                          style: TextStyle(
                                            color: Color(0xff94a3b8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider(color: Color(0xffe2e8f0))),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: widget.auth.busy || !widget.auth.usesApi
                                          ? null
                                          : _signInWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xff172554),
                                        side: const BorderSide(color: Color(0xffdbe3ef)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const _GoogleLogoIcon(),
                                          const SizedBox(width: 11),
                                          Text(
                                            'Continuer avec Google',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
  
                                ],
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() => registering = !registering),
                                  child: Text(registering ? 'Déjà inscrit ? Se connecter' : 'Nouveau sur MediLink ? Créer un compte',
                                    style: const TextStyle(color: Color(0xff2563eb), fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.health_and_safety_outlined, color: Color(0xff0d9488), size: 17),
                            SizedBox(width: 7),
                            Text('Vos échanges de santé en toute confiance',
                              style: TextStyle(color: Color(0xff64748b), fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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


/// Décor médical discret dessiné localement, disponible hors ligne.
class _AuthSoftBackground extends StatelessWidget {
  const _AuthSoftBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _AuthBackgroundPainter(),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xfff4f8ff), Color(0xfffbfdff), Color(0xffeef7ff)],
            ),
          ),
        ),
      );
}

class _AuthBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orb = Paint()..style = PaintingStyle.fill;
    orb.color = const Color(0x2263a5f5);
    canvas.drawCircle(Offset(size.width * 1.02, size.height * .08), size.width * .34, orb);
    orb.color = const Color(0x1c0d9488);
    canvas.drawCircle(Offset(-size.width * .12, size.height * .78), size.width * .30, orb);
    final line = Paint()
      ..color = const Color(0x267aa7d8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .68, size.height * .20)
      ..lineTo(size.width * .77, size.height * .20)
      ..lineTo(size.width * .81, size.height * .16)
      ..lineTo(size.width * .85, size.height * .25)
      ..lineTo(size.width * .89, size.height * .12)
      ..lineTo(size.width * .93, size.height * .20)
      ..lineTo(size.width * 1.02, size.height * .20);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
