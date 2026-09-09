package com.campusmart.service;

import com.campusmart.model.SiteSetting;
import com.campusmart.repository.SiteSettingRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class SiteSettingService {

    private static final Long DEFAULT_ID = 1L;

    @Autowired
    private SiteSettingRepository siteSettingRepository;

    public SiteSetting getSettings() {
        return siteSettingRepository.findById(DEFAULT_ID)
            .orElseGet(this::createDefaultSettings);
    }

    public SiteSetting updateSettings(Map<String, Object> body) {
        SiteSetting settings = getSettings();
        settings.setCompanyName(stringValue(body.get("companyName"), settings.getCompanyName()));
        settings.setCompanyTagline(stringValue(body.get("companyTagline"), settings.getCompanyTagline()));
        settings.setCartLogoUrl(stringValue(body.get("cartLogoUrl"), settings.getCartLogoUrl()));
        settings.setAboutSummary(stringValue(body.get("aboutSummary"), settings.getAboutSummary()));
        settings.setSupportEmail(stringValue(body.get("supportEmail"), settings.getSupportEmail()));
        settings.setBusinessEmail(stringValue(body.get("businessEmail"), settings.getBusinessEmail()));
        settings.setSupportWhatsappNumber(stringValue(body.get("supportWhatsappNumber"), settings.getSupportWhatsappNumber()));
        settings.setSupportHours(stringValue(body.get("supportHours"), settings.getSupportHours()));
        settings.setOfficeAddress(stringValue(body.get("officeAddress"), settings.getOfficeAddress()));
        settings.setInstagramUrl(stringValue(body.get("instagramUrl"), settings.getInstagramUrl()));
        settings.setLinkedinUrl(stringValue(body.get("linkedinUrl"), settings.getLinkedinUrl()));
        settings.setYoutubeUrl(stringValue(body.get("youtubeUrl"), settings.getYoutubeUrl()));
        settings.setXUrl(stringValue(body.get("xUrl"), settings.getXUrl()));
        settings.setGithubUrl(stringValue(body.get("githubUrl"), settings.getGithubUrl()));
        settings.setPrivacyPolicyContent(stringValue(body.get("privacyPolicyContent"), settings.getPrivacyPolicyContent()));
        settings.setTermsContent(stringValue(body.get("termsContent"), settings.getTermsContent()));
        settings.setRefundPolicyContent(stringValue(body.get("refundPolicyContent"), settings.getRefundPolicyContent()));
        settings.setCookiePolicyContent(stringValue(body.get("cookiePolicyContent"), settings.getCookiePolicyContent()));
        settings.setDisclaimerContent(stringValue(body.get("disclaimerContent"), settings.getDisclaimerContent()));
        return siteSettingRepository.save(settings);
    }

    private SiteSetting createDefaultSettings() {
        SiteSetting defaults = new SiteSetting();
        defaults.setId(DEFAULT_ID);
        return siteSettingRepository.save(defaults);
    }

    private String stringValue(Object raw, String fallback) {
        if (raw == null) {
            return fallback;
        }
        return raw.toString().trim();
    }
}
