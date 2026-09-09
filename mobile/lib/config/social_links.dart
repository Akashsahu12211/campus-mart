class SocialLink {
  const SocialLink({
    required this.label,
    required this.shortLabel,
    required this.url,
  });

  final String label;
  final String shortLabel;
  final String url;
}

class SocialLinksConfig {
  static const List<SocialLink> links = [
    SocialLink(
      label: 'Instagram',
      shortLabel: '@campusmart',
      url: String.fromEnvironment('SOCIAL_INSTAGRAM'),
    ),
    SocialLink(
      label: 'LinkedIn',
      shortLabel: 'Campus Mart',
      url: String.fromEnvironment('SOCIAL_LINKEDIN'),
    ),
    SocialLink(
      label: 'YouTube',
      shortLabel: 'Campus Mart',
      url: String.fromEnvironment('SOCIAL_YOUTUBE'),
    ),
    SocialLink(
      label: 'X / Twitter',
      shortLabel: '@campusmart',
      url: String.fromEnvironment('SOCIAL_X'),
    ),
    SocialLink(
      label: 'GitHub',
      shortLabel: 'campus-mart',
      url: String.fromEnvironment('SOCIAL_GITHUB'),
    ),
  ];

  static List<SocialLink> get enabledLinks =>
      links.where((entry) => entry.url.trim().isNotEmpty).toList();
}
