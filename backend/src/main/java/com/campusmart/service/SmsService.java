package com.campusmart.service;

import com.twilio.Twilio;
import com.twilio.rest.api.v2010.account.Message;
import com.twilio.type.PhoneNumber;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class SmsService {

    private static final Logger log = LoggerFactory.getLogger(SmsService.class);

    @Value("${twilio.account.sid:}")
    private String accountSid;

    @Value("${twilio.auth.token:}")
    private String authToken;

    @Value("${twilio.phone.number:}")
    private String fromPhone;

    public boolean sendOtp(String phoneNumber, String otp) {
        if (accountSid == null || accountSid.isBlank() || authToken == null || authToken.isBlank()) {
            log.warn("[SMS] Twilio not configured. Skipping OTP delivery to {}", maskPhone(phoneNumber));
            return false;
        }

        try {
            Twilio.init(accountSid, authToken);
            String toNumber = phoneNumber.startsWith("+") ? phoneNumber : "+91" + phoneNumber;
            log.info("[SMS] Attempting OTP delivery to {}", maskPhone(toNumber));

            Message message = Message.creator(
                    new PhoneNumber(toNumber),
                    new PhoneNumber(fromPhone),
                    "Your Campus Mart OTP is: " + otp + ". Valid for 10 minutes."
            ).create();

            log.info("[SMS] OTP sent successfully. SID={}", message.getSid());
            return true;
        } catch (Exception e) {
            log.error("[SMS] Failed to send OTP to {}: {}", maskPhone(phoneNumber), e.getMessage());
            return false;
        }
    }

    public boolean sendMessage(String phoneNumber, String message) {
        if (accountSid == null || accountSid.isBlank() || authToken == null || authToken.isBlank()) {
            log.warn("[SMS] Twilio not configured. Skipping SMS delivery to {}", maskPhone(phoneNumber));
            return false;
        }

        try {
            Twilio.init(accountSid, authToken);
            String toNumber = phoneNumber.startsWith("+") ? phoneNumber : "+91" + phoneNumber;
            Message.creator(
                    new PhoneNumber(toNumber),
                    new PhoneNumber(fromPhone),
                    message
            ).create();

            log.info("[SMS] Message sent to {}", maskPhone(toNumber));
            return true;
        } catch (Exception e) {
            log.error("[SMS] Failed to send message to {}: {}", maskPhone(phoneNumber), e.getMessage());
            return false;
        }
    }

    private String maskPhone(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.isBlank()) {
            return "(empty)";
        }
        String trimmed = phoneNumber.trim();
        if (trimmed.length() <= 4) {
            return "****";
        }
        return "****" + trimmed.substring(trimmed.length() - 4);
    }
}
