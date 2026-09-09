package com.campusmart.config;

import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import com.campusmart.service.ItemService;
import org.springframework.beans.factory.annotation.Autowired;

@Component
@EnableScheduling
public class SchedulerConfig {

    @Autowired
    private ItemService itemService;

    // ✅ Run daily at 9 AM to send expiry reminders
    @Scheduled(cron = "0 0 9 * * *")
    public void sendExpiryReminders() {
        System.out.println("[SCHEDULER] Running item expiry reminder task...");
        try {
            itemService.sendExpiryReminders();
        } catch (Exception e) {
            System.err.println("[SCHEDULER] Error sending reminders: " + e.getMessage());
            e.printStackTrace();
        }
    }

    // Run every hour to check for expired items
    @Scheduled(cron = "0 0 * * * *")
    public void markExpiredItems() {
        System.out.println("[SCHEDULER] Checking for expired items...");
        try {
            itemService.markExpiredItems();
        } catch (Exception e) {
            System.err.println("[SCHEDULER] Error marking expired items: " + e.getMessage());
        }
    }
}
