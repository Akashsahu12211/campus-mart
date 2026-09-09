package com.campusmart.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class SchedulerService {

    @Autowired
    private ItemService itemService;

    // Scheduling now lives in SchedulerConfig to avoid duplicate reminder jobs.
    public void sendItemExpiryReminders() {
        itemService.sendExpiryReminders();
    }

    public void cleanupExpiredSessions() {
        // Reserved for future cleanup hooks.
    }
}
