const cleanUrl = (value) => value?.trim() || '';

export const SOCIAL_LINKS = [
  {
    key: 'instagram',
    label: 'Instagram',
    short: '@campusmart',
    href: cleanUrl(process.env.REACT_APP_SOCIAL_INSTAGRAM),
  },
  {
    key: 'linkedin',
    label: 'LinkedIn',
    short: 'Campus Mart',
    href: cleanUrl(process.env.REACT_APP_SOCIAL_LINKEDIN),
  },
  {
    key: 'youtube',
    label: 'YouTube',
    short: 'Campus Mart',
    href: cleanUrl(process.env.REACT_APP_SOCIAL_YOUTUBE),
  },
  {
    key: 'x',
    label: 'X / Twitter',
    short: '@campusmart',
    href: cleanUrl(process.env.REACT_APP_SOCIAL_X),
  },
  {
    key: 'github',
    label: 'GitHub',
    short: 'campus-mart',
    href: cleanUrl(process.env.REACT_APP_SOCIAL_GITHUB),
  },
].filter((entry) => entry.href);

export function buildSocialLinksFromSettings(settings = {}) {
  return [
    {
      key: 'instagram',
      label: 'Instagram',
      short: '@campusmart',
      href: cleanUrl(settings.instagramUrl),
    },
    {
      key: 'linkedin',
      label: 'LinkedIn',
      short: 'Campus Mart',
      href: cleanUrl(settings.linkedinUrl),
    },
    {
      key: 'youtube',
      label: 'YouTube',
      short: 'Campus Mart',
      href: cleanUrl(settings.youtubeUrl),
    },
    {
      key: 'x',
      label: 'X / Twitter',
      short: '@campusmart',
      href: cleanUrl(settings.xUrl),
    },
    {
      key: 'github',
      label: 'GitHub',
      short: 'campus-mart',
      href: cleanUrl(settings.githubUrl),
    },
  ].filter((entry) => entry.href);
}
