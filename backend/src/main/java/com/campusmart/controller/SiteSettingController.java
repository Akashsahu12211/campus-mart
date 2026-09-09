package com.campusmart.controller;

import com.campusmart.service.SiteSettingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/public/site-settings")
public class SiteSettingController {

    @Autowired
    private SiteSettingService siteSettingService;

    @GetMapping
    public ResponseEntity<?> getSettings() {
        return ResponseEntity.ok(siteSettingService.getSettings());
    }
}
