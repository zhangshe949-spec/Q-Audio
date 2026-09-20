import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.headphones, size: 48),
            const SizedBox(height: 16),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('来源：本地界面占位，尚未接入音源'),
          ],
        ),
      ),
    ),
  );
}
