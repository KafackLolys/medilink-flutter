import 'package:flutter/material.dart';

class DataList extends StatelessWidget {
  const DataList({
    super.key,
    required this.rows,
    required this.title,
    required this.empty,
    required this.item,
  });

  final List<Map<String, dynamic>> rows;
  final String title;
  final String empty;
  final Widget Function(Map<String, dynamic>) item;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xff17324d),
              ),
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(child: Text(empty)),
          )
        else
          ...rows.map(item),
      ],
    );
  }
}
