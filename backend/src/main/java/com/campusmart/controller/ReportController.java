package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.Item;
import com.campusmart.model.Report;
import com.campusmart.model.Student;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.ReportRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/reports")
public class ReportController {
    private static final long AUTO_HIDE_THRESHOLD = 3L;

    @Autowired private ReportRepository reportRepo;
    @Autowired private ItemRepository itemRepo;

    @PostMapping
    public ResponseEntity<?> submitReport(
        @RequestBody Map<String, Object> body,
        HttpServletRequest request) {
        try {
            Long reporterId = requireAuthenticatedUser(request);
            Long itemId = Long.valueOf(body.get("itemId").toString());
            String reason = body.get("reason").toString().trim();
            String description = body.get("description") != null
                ? body.get("description").toString().trim() : null;

            Item reportedItem = itemRepo.findById(itemId)
                .orElseThrow(() -> new RuntimeException("Item not found"));

            if (reportedItem.getSeller() != null
                && reporterId.equals(reportedItem.getSeller().getId())) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "You cannot report your own listing"));
            }

            if (description != null && description.length() > 1000) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "Description is too long"));
            }

            if ("OTHER".equalsIgnoreCase(reason)
                && (description == null || description.isBlank())) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "Please add details for the moderation team"));
            }

            if (reportRepo.existsByReporterIdAndItemId(reporterId, itemId)) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "Already reported this item"));
            }

            Report r = new Report();
            Student reporter = new Student();
            reporter.setId(reporterId);
            r.setReporter(reporter);
            r.setItem(reportedItem);
            r.setReason(Report.ReportReason.valueOf(reason));
            r.setDescription(description != null && !description.isBlank() ? description : null);

            Report saved = reportRepo.save(r);

            long pendingCount = reportRepo.countByItemIdAndStatus(
                itemId, Report.ReportStatus.PENDING);
            boolean autoHidden = false;
            if (pendingCount >= AUTO_HIDE_THRESHOLD) {
                if (reportedItem.getStatus() == Item.ItemStatus.AVAILABLE ||
                    reportedItem.getStatus() == Item.ItemStatus.RESERVED) {
                    reportedItem.setStatus(Item.ItemStatus.HIDDEN);
                    itemRepo.save(reportedItem);
                }
                autoHidden = true;
            }

            return ResponseEntity.ok(Map.of(
                "report", saved,
                "pendingReports", pendingCount,
                "autoHidden", autoHidden,
                "threshold", AUTO_HIDE_THRESHOLD
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        }
    }

    private Long requireAuthenticatedUser(HttpServletRequest request) {
        return SecurityUtils.getCurrentUserId();
    }
}
