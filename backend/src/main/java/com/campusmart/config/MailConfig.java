package com.campusmart.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;

import java.util.Properties;

@Configuration
public class MailConfig {

    @Bean
    public JavaMailSender javaMailSender(
            @Value("${spring.mail.host:smtp.gmail.com}") String host,
            @Value("${spring.mail.port:587}") int port,
            @Value("${spring.mail.username:}") String username,
            @Value("${spring.mail.password:}") String password
    ) {
        JavaMailSenderImpl mailSender = new JavaMailSenderImpl();
        mailSender.setHost(host);
        mailSender.setPort(port);
        mailSender.setUsername(username == null ? "" : username.trim());
        mailSender.setPassword(password == null ? "" : password.trim());
        mailSender.setDefaultEncoding("UTF-8");

        Properties props = mailSender.getJavaMailProperties();
        props.put("mail.transport.protocol", "smtp");
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.auth.mechanisms", "PLAIN");
        props.put("mail.smtp.auth.login.disable", "true");
        props.put("mail.smtp.auth.plain.disable", "false");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.starttls.required", "true");
        props.put("mail.smtp.ssl.protocols", "TLSv1.2");
        props.put("mail.smtp.ssl.trust", "smtp.gmail.com");
        props.put("mail.smtp.connectiontimeout", "10000");
        props.put("mail.smtp.timeout", "10000");
        props.put("mail.smtp.writetimeout", "10000");
        props.put("mail.debug", "true");

        System.out.println("[MAIL CONFIG] username=" + maskUsername(username)
                + ", passwordSet=" + (password != null && !password.isBlank())
                + ", passwordLength=" + (password != null ? password.trim().length() : 0));

        return mailSender;
    }

    private String maskUsername(String username) {
        if (username == null || username.isBlank()) {
            return "(empty)";
        }
        int at = username.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        return username.charAt(0) + "***" + username.substring(at);
    }
}
