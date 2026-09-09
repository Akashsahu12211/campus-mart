import 'package:flutter/material.dart';

class LegalDetailScreen extends StatelessWidget {
  final String title;
  final String intro;
  final List<Map<String, String>> sections;

  const LegalDetailScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(intro,
              style: const TextStyle(color: Color(0xFFB6BFD8), height: 1.6)),
          const SizedBox(height: 20),
          ...sections.map((section) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1320),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2438)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section['title'] ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(section['body'] ?? '',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), height: 1.5)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
