import 'package:flutter/material.dart';

/// Shared MedLink mark used on login and authenticated screens.
class MedilinkLogoMark extends StatelessWidget {
  const MedilinkLogoMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.favorite,
        size: size,
        color: const Color(0xff1769aa),
      );
}
