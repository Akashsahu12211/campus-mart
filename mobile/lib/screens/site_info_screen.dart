import 'package:flutter/material.dart';

class SiteInfoScreen extends StatelessWidget {
  const SiteInfoScreen({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.sections,
    this.actions = const [],
  });

  final String title;
  final String eyebrow;
  final String description;
  final List<SiteInfoSection> sections;
  final List<SiteInfoAction> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2440), Color(0xFF0F1320)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFF2A3558)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Color(0xFF8EA0D8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFB6BFD8),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions
                  .map(
                    (action) => action.isPrimary
                        ? ElevatedButton(
                            onPressed: action.onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              action.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: action.onTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF2A3558),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              action.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          ...sections.map(
            (section) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1320),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E2438)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: const TextStyle(
                      color: Color(0xFFB6BFD8),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SiteInfoSection {
  const SiteInfoSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class SiteInfoAction {
  const SiteInfoAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
}
