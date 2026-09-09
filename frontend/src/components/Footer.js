import React from 'react';
import { Link } from 'react-router-dom';
import {
  SUPPORT_BUSINESS_EMAIL,
  SUPPORT_EMAIL,
  SUPPORT_WHATSAPP_LINK,
} from '../config/support';
import { SOCIAL_LINKS, buildSocialLinksFromSettings } from '../config/socials';
import { useSiteSettings } from '../context/SiteSettingsContext';
import '../styles/Footer.css';

export default function Footer() {
  const { settings } = useSiteSettings();
  const companyName = settings.companyName || 'Campus Mart';
  const aboutSummary = settings.aboutSummary || 'A student-first campus marketplace with safer buying, clearer support, and a more professional experience across web and app.';
  const supportEmail = settings.supportEmail || SUPPORT_EMAIL;
  const businessEmail = settings.businessEmail || SUPPORT_BUSINESS_EMAIL;
  const whatsappLink = settings.supportWhatsappLink || SUPPORT_WHATSAPP_LINK;
  const socialLinks = buildSocialLinksFromSettings(settings);
  const visibleSocialLinks = socialLinks.length > 0 ? socialLinks : SOCIAL_LINKS;
  const supportContacts = [
    { label: supportEmail, href: `mailto:${supportEmail}` },
    ...(businessEmail && businessEmail !== supportEmail
      ? [{ label: businessEmail, href: `mailto:${businessEmail}` }]
      : []),
    ...(whatsappLink
      ? [{ label: 'WhatsApp Support', href: whatsappLink, external: true }]
      : []),
  ];

  return (
    <footer className="site-footer">
      <div className="site-footer__inner">
        <div className="site-footer__column">
          <div className="site-footer__brand">{companyName}</div>
          <p className="site-footer__summary">{aboutSummary}</p>
          {visibleSocialLinks.length > 0 && (
            <div className="site-footer__socials">
              {visibleSocialLinks.map((social) => (
                <a
                  key={social.key}
                  href={social.href}
                  target="_blank"
                  rel="noreferrer"
                  className="site-footer__social-link"
                >
                  {social.label}
                </a>
              ))}
            </div>
          )}
        </div>

        <div className="site-footer__column">
          <div className="site-footer__title">Company</div>
          <Link to="/about">About Us</Link>
          <Link to="/contact">Contact Us</Link>
          <Link to="/help">Help Center</Link>
          <Link to="/faq">FAQ</Link>
        </div>

        <div className="site-footer__column">
          <div className="site-footer__title">Trust & Legal</div>
          <Link to="/privacy-policy">Privacy Policy</Link>
          <Link to="/terms-and-conditions">Terms & Conditions</Link>
          <Link to="/refund-policy">Refund Policy</Link>
          <Link to="/cookie-policy">Cookie Policy</Link>
          <Link to="/disclaimer">Disclaimer</Link>
          <Link to="/community-guidelines">Community Guidelines</Link>
        </div>

        <div className="site-footer__column">
          <div className="site-footer__title">Support</div>
          {supportContacts.map((contact) => (
            <a
              key={contact.label}
              href={contact.href}
              target={contact.external ? '_blank' : undefined}
              rel={contact.external ? 'noreferrer' : undefined}
            >
              {contact.label}
            </a>
          ))}
          <Link to="/feedback">Feedback</Link>
          <Link to="/report-problem">Report a Problem</Link>
          <div className="site-footer__hours">
            {settings.supportHours || 'Mon-Sat, 10 AM - 7 PM'}
          </div>
        </div>
      </div>
    </footer>
  );
}
