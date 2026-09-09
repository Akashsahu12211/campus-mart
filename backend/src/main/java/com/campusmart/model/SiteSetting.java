package com.campusmart.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "site_settings")
@Data
@NoArgsConstructor
public class SiteSetting {

    @Id
    private Long id = 1L;

    @Column(name = "company_name")
    private String companyName = "Campus Mart";

    @Column(name = "company_tagline")
    private String companyTagline = "Student-first campus marketplace";

    @Lob
    @Column(name = "cart_logo_url")
    private String cartLogoUrl = "";

    @Lob
    @Column(name = "about_summary")
    private String aboutSummary = "Campus Mart helps students buy, sell, discover, and support each other inside safer campus communities.";

    @Column(name = "support_email")
    private String supportEmail = "support@your-domain.com";

    @Column(name = "business_email")
    private String businessEmail = "business@your-domain.com";

    @Column(name = "support_whatsapp_number")
    private String supportWhatsappNumber = "";

    @Column(name = "support_hours")
    private String supportHours = "Mon-Sat, 10 AM - 7 PM";

    @Lob
    @Column(name = "office_address")
    private String officeAddress = "Add your startup office or campus support address here.";

    @Column(name = "instagram_url")
    private String instagramUrl = "";

    @Column(name = "linkedin_url")
    private String linkedinUrl = "";

    @Column(name = "youtube_url")
    private String youtubeUrl = "";

    @Column(name = "x_url")
    private String xUrl = "";

    @Column(name = "github_url")
    private String githubUrl = "";

    @Lob
    @Column(name = "privacy_policy_content")
    private String privacyPolicyContent = "Replace this placeholder with your full privacy policy. Include what data you collect, why, how long you keep it, and how users can contact you.";

    @Lob
    @Column(name = "terms_content")
    private String termsContent = "Replace this placeholder with your terms and conditions. Explain permitted use, prohibited activity, moderation rights, and account responsibilities.";

    @Lob
    @Column(name = "refund_policy_content")
    private String refundPolicyContent = "Replace this placeholder with your refund and dispute workflow. Explain when refunds may apply, who reviews them, and what proof is required.";

    @Lob
    @Column(name = "cookie_policy_content")
    private String cookiePolicyContent = "Replace this placeholder with your cookie and local storage policy. Explain session, preference, and security storage usage.";

    @Lob
    @Column(name = "disclaimer_content")
    private String disclaimerContent = "Replace this placeholder with your legal disclaimer. Explain that users remain responsible for truthful listings and safe transactions.";
}
