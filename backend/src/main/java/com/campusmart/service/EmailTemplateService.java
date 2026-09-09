package com.campusmart.service;

import com.campusmart.model.Item;
import com.campusmart.model.Offer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Service
public class EmailTemplateService {

    @Value("${app.frontend.base-url:}")
    private String frontendBaseUrl;

    public String buildOtpEmail(String name, String otp, String purpose) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(name) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 22px;'>Your OTP for " + safe(purpose) + " is:</p>"
                + "<div style='background:#f8f9ff;border:2px dashed #5B4BFF;border-radius:18px;padding:28px 20px;text-align:center;margin:0 0 20px;'>"
                + "<span style='font-size:40px;font-weight:900;letter-spacing:12px;color:#5B4BFF;'>" + safe(otp) + "</span>"
                + "</div>"
                + "<p style='color:#6b7280;font-size:14px;margin:0 0 8px;'>This OTP expires in <strong>10 minutes</strong>.</p>"
                + "<p style='color:#6b7280;font-size:14px;margin:0;'>Never share this OTP with anyone.</p>";

        return buildTemplate(
                purpose,
                bodyHtml,
                null,
                null,
                "If you did not request this OTP, you can safely ignore this email."
        );
    }

    public String buildWelcomeEmail(String name) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(name) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Your Campus Mart account is now verified and ready to use.</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0;'>Start buying and selling with students on your campus.</p>";

        return buildTemplate(
                "Welcome to Campus Mart",
                bodyHtml,
                "Start Exploring",
                resolveFrontendUrl(""),
                "Thanks for joining Campus Mart."
        );
    }

    public String buildGenericMessageEmail(String title, String recipientName, String message, String ctaLabel, String ctaUrl) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<div style='color:#4b5563;line-height:1.8;font-size:16px;margin:0;'>" + nl2br(message) + "</div>";

        return buildTemplate(title, bodyHtml, ctaLabel, ctaUrl, "Campus Mart will never ask for your password over email.");
    }

    public String buildNewItemAddedEmail(String recipientName, Item item) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>A new item has just been listed on Campus Mart and might be relevant for you.</p>"
                + buildDetailsCard(List.of(
                        detailRow("Item", safe(item.getTitle())),
                        detailRow("Price", price(item.getPrice())),
                        detailRow("Category", item.getCategory() != null ? safe(item.getCategory().getName()) : "Uncategorized"),
                        detailRow("Seller", item.getSeller() != null ? safe(item.getSeller().getName()) : "Campus Mart Seller"),
                        detailRow("Description", safe(shortDescription(item.getDescription())))
                ));

        return buildTemplate(
                "New Item Added on Campus Mart",
                bodyHtml,
                "View Item",
                resolveFrontendUrl("/item/" + item.getId()),
                "Open Campus Mart to message the seller or explore more listings."
        );
    }

    public String buildChatMessageEmail(String recipientName, String senderName, String messagePreview) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'><strong>" + safe(senderName) + "</strong> sent you a new message on Campus Mart.</p>"
                + "<div style='background:#f8f9ff;border:1px solid #e5e7eb;border-radius:16px;padding:18px;margin:0;'>"
                + "<p style='margin:0;color:#111827;font-size:15px;line-height:1.7;'>" + safe(messagePreview) + "</p>"
                + "</div>";

        return buildTemplate(
                "New Message on Campus Mart",
                bodyHtml,
                "Open Chat",
                resolveFrontendUrl("/chat"),
                "Reply quickly so you do not miss the conversation."
        );
    }

    public String buildOfferReceivedEmail(String recipientName, Offer offer) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>You have received a new offer for one of your listings.</p>"
                + buildDetailsCard(buildOfferDetails(offer, true));

        return buildTemplate(
                "New Offer Received",
                bodyHtml,
                "Review Offer",
                resolveFrontendUrl("/my-items"),
                "Respond from Campus Mart to accept, reject, or continue the conversation."
        );
    }

    public String buildOfferStatusEmail(String recipientName, Offer offer) {
        String status = offer.getStatus() != null ? offer.getStatus().name() : "UPDATED";
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>The seller has updated your offer status.</p>"
                + buildDetailsCard(List.of(
                        detailRow("Item", offer.getItem() != null ? safe(offer.getItem().getTitle()) : "Campus Mart Item"),
                        detailRow("Offer Status", safe(capitalize(status))),
                        detailRow("Offered Price", price(offer.getOfferedPrice()))
                ));

        return buildTemplate(
                "Your Offer Status Updated",
                bodyHtml,
                "View Offer",
                resolveFrontendUrl("/orders"),
                "You can continue from your Campus Mart account for the next steps."
        );
    }

    public String buildItemReservedEmail(String recipientName, Item item, String buyerName) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'><strong>" + safe(buyerName) + "</strong> has reserved your item.</p>"
                + buildDetailsCard(List.of(
                        detailRow("Item", safe(item.getTitle())),
                        detailRow("Price", price(item.getPrice())),
                        detailRow("Buyer", safe(buyerName))
                ));

        return buildTemplate(
                "Your Item Has Been Reserved",
                bodyHtml,
                "Open My Listings",
                resolveFrontendUrl("/my-items"),
                "Connect with the buyer from Campus Mart to close the deal smoothly."
        );
    }

    public String buildItemExpiryReminderEmail(String recipientName, Item item) {
        String bodyHtml = ""
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Hi <strong>" + safe(recipientName) + "</strong>,</p>"
                + "<p style='color:#4b5563;line-height:1.8;font-size:16px;margin:0 0 18px;'>Your item will expire soon if you do not refresh or relist it.</p>"
                + buildDetailsCard(List.of(
                        detailRow("Item", safe(item.getTitle())),
                        detailRow("Current Price", price(item.getPrice())),
                        detailRow("Status", "Expires soon")
                ));

        return buildTemplate(
                "Your Item Will Expire Soon",
                bodyHtml,
                "Manage Listing",
                resolveFrontendUrl("/my-items"),
                "Relist or update the item from Campus Mart to keep it visible."
        );
    }

    private List<String> buildOfferDetails(Offer offer, boolean includeMessage) {
        List<String> details = new ArrayList<>();
        details.add(detailRow("Buyer", offer.getBuyer() != null ? safe(offer.getBuyer().getName()) : "Campus Mart Buyer"));
        details.add(detailRow("Item", offer.getItem() != null ? safe(offer.getItem().getTitle()) : "Campus Mart Item"));
        details.add(detailRow("Original Price", offer.getItem() != null ? price(offer.getItem().getPrice()) : "-"));
        details.add(detailRow("Offered Price", price(offer.getOfferedPrice())));
        if (includeMessage && offer.getNote() != null && !offer.getNote().isBlank()) {
            details.add(detailRow("Message", safe(offer.getNote())));
        }
        return details;
    }

    private String buildTemplate(String title, String bodyHtml, String ctaLabel, String ctaUrl, String footerNote) {
        String ctaHtml = "";
        if (ctaLabel != null && ctaUrl != null && !ctaLabel.isBlank() && !ctaUrl.isBlank()) {
            ctaHtml = ""
                    + "<div style='margin-top:28px;'>"
                    + "<a href='" + safeAttribute(ctaUrl) + "' style='display:inline-block;background:linear-gradient(135deg,#1E3A5F,#5B4BFF);color:#ffffff;text-decoration:none;padding:14px 24px;border-radius:12px;font-weight:700;'>"
                    + safe(ctaLabel)
                    + "</a>"
                    + "</div>";
        }

        return "<!DOCTYPE html><html><body style='margin:0;padding:24px 12px;background:#f3f4f6;font-family:Arial,sans-serif;'>"
                + "<div style='max-width:640px;margin:0 auto;background:#ffffff;border-radius:22px;overflow:hidden;box-shadow:0 18px 45px rgba(15,23,42,0.12);'>"
                + "<div style='background:linear-gradient(135deg,#1E3A5F,#5B4BFF);padding:38px 28px;text-align:center;'>"
                + "<div style='font-size:34px;line-height:1;margin-bottom:10px;'>&#128722;</div>"
                + "<h1 style='color:#ffffff;margin:0;font-size:36px;font-weight:800;'>Campus Mart</h1>"
                + "<p style='color:rgba(255,255,255,0.85);margin:10px 0 0;font-size:17px;'>College Student Marketplace</p>"
                + "</div>"
                + "<div style='padding:38px 40px 30px;'>"
                + "<h2 style='color:#1E3A5F;margin:0 0 22px;font-size:34px;font-weight:800;'>" + safe(title) + "</h2>"
                + bodyHtml
                + ctaHtml
                + "<p style='color:#6b7280;font-size:13px;line-height:1.7;margin:28px 0 0;'>" + safe(footerNote) + "</p>"
                + "</div>"
                + "<div style='background:#f8f9ff;padding:18px 28px;text-align:center;border-top:1px solid #e5e7eb;'>"
                + "<p style='margin:0;color:#9ca3af;font-size:12px;'>Campus Mart | College Student Marketplace</p>"
                + "</div>"
                + "</div>"
                + "</body></html>";
    }

    private String buildDetailsCard(List<String> rows) {
        return "<div style='background:#f8f9ff;border:1px solid #e5e7eb;border-radius:18px;padding:20px;margin:0;'>"
                + String.join("", rows)
                + "</div>";
    }

    private String detailRow(String label, String value) {
        return ""
                + "<div style='padding:10px 0;border-bottom:1px solid #e5e7eb;'>"
                + "<div style='font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.08em;margin-bottom:4px;'>" + safe(label) + "</div>"
                + "<div style='font-size:15px;color:#111827;line-height:1.6;'>" + value + "</div>"
                + "</div>";
    }

    private String price(BigDecimal value) {
        return value != null ? "&#8377;" + safe(value.stripTrailingZeros().toPlainString()) : "-";
    }

    private String price(Double value) {
        return value != null ? "&#8377;" + safe(String.format("%.2f", value)) : "-";
    }

    private String shortDescription(String description) {
        if (description == null || description.isBlank()) {
            return "No description provided";
        }
        String trimmed = description.trim();
        return trimmed.length() > 160 ? trimmed.substring(0, 157) + "..." : trimmed;
    }

    private String capitalize(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String lower = value.toLowerCase();
        return Character.toUpperCase(lower.charAt(0)) + lower.substring(1);
    }

    private String nl2br(String value) {
        return safe(value).replace("\n", "<br/>");
    }

    private String safe(String value) {
        if (value == null) {
            return "";
        }
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    private String safeAttribute(String value) {
        return safe(value);
    }

    private String resolveFrontendUrl(String path) {
        String base = frontendBaseUrl == null ? "" : frontendBaseUrl.trim();
        if (base.isBlank()) {
            base = "https://mycampusmart.in";
        }

        String normalizedBase = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        if (path == null || path.isBlank()) {
            return normalizedBase;
        }

        return path.startsWith("/") ? normalizedBase + path : normalizedBase + "/" + path;
    }
}
