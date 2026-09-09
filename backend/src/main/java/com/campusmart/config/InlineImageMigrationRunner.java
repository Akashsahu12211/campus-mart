package com.campusmart.config;

import com.campusmart.service.LegacyItemImageMigrationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class InlineImageMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(InlineImageMigrationRunner.class);

    private final LegacyItemImageMigrationService legacyItemImageMigrationService;

    @Value("${app.maintenance.migrate-inline-item-images-on-startup:false}")
    private boolean migrateOnStartup;

    @Value("${app.maintenance.inline-image-migration-limit:0}")
    private int migrationLimit;

    public InlineImageMigrationRunner(LegacyItemImageMigrationService legacyItemImageMigrationService) {
        this.legacyItemImageMigrationService = legacyItemImageMigrationService;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!migrateOnStartup) {
            return;
        }

        Integer limit = migrationLimit <= 0 ? null : migrationLimit;
        var before = legacyItemImageMigrationService.getInlineImageStats();
        log.info("Starting legacy inline item image migration. Current stats={}", before);
        var result = legacyItemImageMigrationService.migrateInlineImages(limit);
        log.info("Completed legacy inline item image migration. Result={}", result);
    }
}
