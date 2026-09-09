package com.campusmart.service;

import com.campusmart.model.*;
import com.campusmart.model.AdminLog.TargetType;
import com.campusmart.model.Item.ItemStatus;
import com.campusmart.model.Report.ReportStatus;
import com.campusmart.model.Student.StudentRole;
import com.campusmart.model.SupportRequest.SupportStatus;
import com.campusmart.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.*;

@Service
public class AdminService {

    @Autowired private StudentRepository studentRepo;
    @Autowired private ItemRepository    itemRepo;
    @Autowired private ReportRepository  reportRepo;
    @Autowired private AdminLogRepository logRepo;
    @Autowired private MessageRepository msgRepo;
    @Autowired private OfferRepository   offerRepo;
    @Autowired private PaymentOrderRepository paymentRepo;
    @Autowired private PaymentService paymentService;
    @Autowired private SupportRequestRepository supportRepo;
    @Autowired private SiteSettingService siteSettingService;
    @Autowired private LegacyItemImageMigrationService legacyItemImageMigrationService;

    // ── Role Check Utility ────────────────────────────────────
    public void requireAdmin(Long adminId) {
        Student admin = studentRepo.findById(adminId)
            .orElseThrow(() -> new RuntimeException("Admin not found"));
        if (admin.getRole() != StudentRole.ADMIN) {
            throw new RuntimeException("Unauthorized: Admin access required");
        }
    }

    public void requireSuperAdmin(Long adminId) {
        requireAdmin(adminId);
    }

    // ── Dashboard Analytics ───────────────────────────────────
    public Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new LinkedHashMap<>();

        // Users
        long totalUsers     = studentRepo.count();
        long bannedUsers    = studentRepo.countByIsBanned(true);
        long adminCount     = studentRepo.countByRole(StudentRole.ADMIN);
        long modCount       = studentRepo.countByRole(StudentRole.MODERATOR);

        // Items
        long totalItems     = itemRepo.count();
        long availableItems = itemRepo.countByStatus(ItemStatus.AVAILABLE);
        long soldItems      = itemRepo.countByStatus(ItemStatus.SOLD);
        long hiddenItems    = itemRepo.countByStatus(ItemStatus.HIDDEN);
        long expiredItems   = itemRepo.countByStatus(ItemStatus.EXPIRED);

        // Reports
        long pendingReports = reportRepo.countByStatus(ReportStatus.PENDING);
        long totalReports   = reportRepo.count();

        // Today stats
        LocalDateTime todayStart =
            LocalDateTime.now().withHour(0).withMinute(0).withSecond(0);
        long todayUsers = studentRepo.countByCreatedAtAfter(todayStart);
        long todayItems = itemRepo.countByCreatedAtAfter(todayStart);
        long totalOrders = safeCount(() -> paymentRepo.count());
        long completedOrders = safeCount(() -> (long) paymentRepo.findByStatus(PaymentOrder.PaymentStatus.RELEASED).size());
        long disputedOrders = safeCount(() -> (long) paymentRepo.findByStatus(PaymentOrder.PaymentStatus.DISPUTED).size());
        long resolvedSupport = safeCount(() -> supportRepo.countByStatus(SupportStatus.RESOLVED));
        java.math.BigDecimal gmvReleased = safeAmount(() -> paymentRepo.sumReleasedAmount());
        java.math.BigDecimal gmvPending = safeAmount(() -> paymentRepo.sumPendingAmount());
        java.math.BigDecimal grossMerchandiseValue = gmvReleased.add(gmvPending);
        long plusSubscribers = safeCount(() -> studentRepo.countByActiveSubscriptionCode("PLUS"));
        long premiumSubscribers = safeCount(() -> studentRepo.countByActiveSubscriptionCode("PREMIUM"));
        long activeBoostedListings = safeCount(() -> itemRepo.countByBoostExpiresAtAfter(LocalDateTime.now()));
        java.math.BigDecimal releasedPlatformFees = safeAmount(() -> paymentRepo.sumReleasedPlatformFees());
        java.math.BigDecimal pendingPlatformFees = safeAmount(() -> paymentRepo.sumPendingPlatformFees());

        stats.put("users", Map.of(
            "total",   totalUsers,
            "banned",  bannedUsers,
            "admins",  adminCount,
            "mods",    modCount,
            "today",   todayUsers
        ));
        stats.put("items", Map.of(
            "total",     totalItems,
            "available", availableItems,
            "sold",      soldItems,
            "hidden",    hiddenItems,
            "expired",   expiredItems,
            "today",     todayItems
        ));
        stats.put("reports", Map.of(
            "pending", pendingReports,
            "total",   totalReports
        ));
        stats.put("platform", Map.of(
            "totalMessages", safeCount(() -> msgRepo.count()),
            "totalOffers",   safeCount(() -> offerRepo.count())
        ));
        stats.put("support", Map.of(
            "open",      safeCount(() -> supportRepo.countByStatus(SupportStatus.OPEN)),
            "inProgress", safeCount(() -> supportRepo.countByStatus(SupportStatus.IN_PROGRESS)),
            "total",     safeCount(() -> supportRepo.count()),
            "resolved",  resolvedSupport,
            "feedback",  safeCount(() -> supportRepo.countByType(SupportRequest.SupportType.FEEDBACK)),
            "problems",  safeCount(() -> supportRepo.countByType(SupportRequest.SupportType.PROBLEM_REPORT))
        ));
        stats.put("analytics", Map.of(
            "gmv", grossMerchandiseValue,
            "orders", totalOrders,
            "completedOrders", completedOrders,
            "disputedOrders", disputedOrders,
            "conversionRate", totalItems == 0 ? 0 : Math.round(((double) soldItems / (double) totalItems) * 1000.0) / 10.0,
            "supportResolutionRate", safeResolutionRate(resolvedSupport, safeCount(() -> supportRepo.count())),
            "googleUsers", safeCount(() -> studentRepo.countByAuthProvider(Student.AuthProvider.GOOGLE)),
            "facebookUsers", safeCount(() -> studentRepo.countByAuthProvider(Student.AuthProvider.FACEBOOK)),
            "localUsers", safeCount(() -> studentRepo.countByAuthProvider(Student.AuthProvider.LOCAL))
        ));
        stats.put("monetization", Map.of(
            "plusSubscribers", plusSubscribers,
            "premiumSubscribers", premiumSubscribers,
            "paidSubscribers", plusSubscribers + premiumSubscribers,
            "activeBoostedListings", activeBoostedListings,
            "releasedPlatformFees", releasedPlatformFees,
            "pendingPlatformFees", pendingPlatformFees
        ));

        return stats;
    }

    // Chart: New users per day (last 7 days)
    public List<Map<String, Object>> getUserGrowthChart() {
        List<Map<String, Object>> chart = new ArrayList<>();
        for (int i = 6; i >= 0; i--) {
            LocalDateTime start =
                LocalDateTime.now().minusDays(i)
                    .withHour(0).withMinute(0).withSecond(0);
            LocalDateTime end =
                LocalDateTime.now().minusDays(i)
                    .withHour(23).withMinute(59).withSecond(59);
            long count = studentRepo.countByCreatedAtBetween(start, end);
            chart.add(Map.of(
                "date",  start.toLocalDate().toString(),
                "day",   start.getDayOfWeek().name().substring(0,3),
                "users", count
            ));
        }
        return chart;
    }

    // Chart: Listings per day (last 7 days)
    public List<Map<String, Object>> getListingsChart() {
        List<Map<String, Object>> chart = new ArrayList<>();
        for (int i = 6; i >= 0; i--) {
            LocalDateTime start =
                LocalDateTime.now().minusDays(i)
                    .withHour(0).withMinute(0).withSecond(0);
            LocalDateTime end =
                LocalDateTime.now().minusDays(i)
                    .withHour(23).withMinute(59).withSecond(59);
            long count = itemRepo.countByCreatedAtBetween(start, end);
            chart.add(Map.of(
                "date",   start.toLocalDate().toString(),
                "day",    start.getDayOfWeek().name().substring(0,3),
                "items",  count
            ));
        }
        return chart;
    }

    // Category distribution
    public List<Map<String, Object>> getCategoryDistribution() {
        List<Object[]> raw = itemRepo.countByCategory();
        List<Map<String, Object>> result = new ArrayList<>();
        for (Object[] row : raw) {
            result.add(Map.of(
                "category", row[0] != null ? row[0] : "Unknown",
                "count",    row[1]
            ));
        }
        return result;
    }

    // ── User Management ───────────────────────────────────────
    public List<Student> getAllUsers() {
        return studentRepo.findAllByOrderByCreatedAtDesc();
    }

    public List<Student> searchUsers(String q) {
        return studentRepo
            .findByNameContainingIgnoreCaseOrEmailContainingIgnoreCase(q, q);
    }

    public Student changeUserRole(
        Long adminId, Long targetId, StudentRole newRole) {
        requireSuperAdmin(adminId);
        Student target = studentRepo.findById(targetId)
            .orElseThrow(() -> new RuntimeException("User not found"));

        // Cannot change own role
        if (targetId.equals(adminId)) {
            throw new RuntimeException(
                "Cannot change your own role");
        }

        StudentRole oldRole = target.getRole();
        target.setRole(newRole);
        Student saved = studentRepo.save(target);

        log(adminId, "CHANGE_ROLE", TargetType.USER, targetId,
            "Changed role from " + oldRole + " to " + newRole +
            " for user: " + target.getName());
        return saved;
    }

    public Student banUser(
        Long adminId, Long targetId, String reason) {
        requireAdmin(adminId);
        Student target = studentRepo.findById(targetId)
            .orElseThrow(() -> new RuntimeException("User not found"));

        if (targetId.equals(adminId)) {
            throw new RuntimeException("Cannot ban yourself");
        }
        if (target.getRole() == StudentRole.ADMIN) {
            throw new RuntimeException("Cannot ban an admin");
        }

        target.setIsBanned(true);
        target.setBanReason(reason);
        target.setBannedAt(LocalDateTime.now());
        Student saved = studentRepo.save(target);

        log(adminId, "BAN_USER", TargetType.USER, targetId,
            "Banned: " + target.getName() + " | Reason: " + reason);
        return saved;
    }

    public Student unbanUser(Long adminId, Long targetId) {
        requireAdmin(adminId);
        Student target = studentRepo.findById(targetId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        target.setIsBanned(false);
        target.setBanReason(null);
        target.setBannedAt(null);
        Student saved = studentRepo.save(target);

        log(adminId, "UNBAN_USER", TargetType.USER, targetId,
            "Unbanned: " + target.getName());
        return saved;
    }

    public void deleteUser(Long adminId, Long targetId) {
        requireSuperAdmin(adminId);
        if (targetId.equals(adminId)) {
            throw new RuntimeException("Cannot delete yourself");
        }
        Student target = studentRepo.findById(targetId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        String name = target.getName();
        studentRepo.deleteById(targetId);
        log(adminId, "DELETE_USER", TargetType.USER, targetId,
            "Deleted user: " + name);
    }

    // ── Item Moderation ───────────────────────────────────────
    public List<Item> getAllItemsAdmin() {
        return itemRepo.findAllByOrderByCreatedAtDesc();
    }

    public List<Item> getItemsByStatus(String status) {
        try {
            return itemRepo.findByStatusOrderByCreatedAtDesc(
                ItemStatus.valueOf(status.toUpperCase()));
        } catch (Exception e) {
            return itemRepo.findAll();
        }
    }

    public Item hideItem(Long adminId, Long itemId, String reason) {
        requireAdmin(adminId);
        Item item = itemRepo.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found"));
        item.setStatus(ItemStatus.HIDDEN);
        Item saved = itemRepo.save(item);
        log(adminId, "HIDE_ITEM", TargetType.ITEM, itemId,
            "Hidden: " + item.getTitle() + " | Reason: " + reason);
        return saved;
    }

    public Item restoreItem(Long adminId, Long itemId) {
        requireAdmin(adminId);
        Item item = itemRepo.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found"));
        item.setStatus(ItemStatus.AVAILABLE);
        Item saved = itemRepo.save(item);
        log(adminId, "RESTORE_ITEM", TargetType.ITEM, itemId,
            "Restored: " + item.getTitle());
        return saved;
    }

    public void forceDeleteItem(Long adminId, Long itemId) {
        requireAdmin(adminId);
        Item item = itemRepo.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found"));
        String title = item.getTitle();
        itemRepo.deleteById(itemId);
        log(adminId, "FORCE_DELETE_ITEM", TargetType.ITEM, itemId,
            "Force deleted: " + title);
    }

    // ── Report Management ─────────────────────────────────────
    public List<Report> getAllReports() {
        List<Report> reports = reportRepo.findAllByOrderByCreatedAtDesc();
        reports.forEach(this::enrichReport);
        return reports;
    }

    public List<Report> getPendingReports() {
        List<Report> reports = reportRepo.findByStatusOrderByCreatedAtDesc(
            ReportStatus.PENDING);
        reports.forEach(this::enrichReport);
        return reports;
    }

    public Report reviewReport(
        Long adminId, Long reportId, String action) {
        requireAdmin(adminId);
        Report report = reportRepo.findById(reportId)
            .orElseThrow(() -> new RuntimeException("Report not found"));

        Student reviewer = studentRepo.findById(adminId)
            .orElseThrow(() -> new RuntimeException("Admin not found"));
        report.setReviewedBy(reviewer);
        report.setReviewedAt(LocalDateTime.now());

        if ("dismiss".equalsIgnoreCase(action)) {
            report.setStatus(ReportStatus.DISMISSED);
            report.setResolutionNote("Dismissed after moderation review");
        } else if ("approve".equalsIgnoreCase(action)) {
            report.setStatus(ReportStatus.REVIEWED);
            report.setResolutionNote("Approved after moderation review");
            // Hide the item
            Item item = report.getItem();
            if (item != null) {
                item.setStatus(ItemStatus.HIDDEN);
                itemRepo.save(item);
                if (item.getSeller() != null) {
                    Student seller = item.getSeller();
                    seller.setModerationStrikeCount(
                        (seller.getModerationStrikeCount() != null
                            ? seller.getModerationStrikeCount()
                            : 0) + 1
                    );
                    studentRepo.save(seller);
                }
            }
        } else {
            throw new RuntimeException("Invalid report action");
        }

        Report saved = reportRepo.save(report);
        enrichReport(saved);
        log(adminId, "REVIEW_REPORT", TargetType.ITEM,
            report.getItem() != null ? report.getItem().getId() : null,
            "Report " + action + "d: " + reportId);
        return saved;
    }

    // ── Payment Disputes (Escrow) ─────────────────────────────
    public List<PaymentOrder> getDisputedPayments() {
        return paymentRepo.findByStatus(
            PaymentOrder.PaymentStatus.DISPUTED);
    }

    public Map<String, Object> resolveDispute(
            Long adminId, Long orderId,
            String action, String reason) {
        requireAdmin(adminId);

        PaymentOrder order = paymentRepo.findById(orderId)
            .orElseThrow(() -> new RuntimeException("Order not found"));

        if (order.getStatus() != PaymentOrder.PaymentStatus.DISPUTED) {
            throw new RuntimeException(
                "Order is not in disputed state");
        }

        if ("REFUND".equalsIgnoreCase(action)) {
            // Refund to buyer
            Map<String, Object> result =
                paymentService.refundOrder(orderId, adminId, reason);
            log(adminId, "RESOLVE_DISPUTE_REFUND",
                TargetType.ITEM, order.getItem().getId(),
                "Dispute resolved with refund: " + reason);
            return result;
        } else if ("RELEASE".equalsIgnoreCase(action)) {
            // Release to seller
            order.setStatus(PaymentOrder.PaymentStatus.RELEASED);
            order.setEscrowReleased(true);
            order.setUpdatedAt(LocalDateTime.now());
            paymentRepo.save(order);
            log(adminId, "RESOLVE_DISPUTE_RELEASE",
                TargetType.ITEM, order.getItem().getId(),
                "Dispute resolved with release to seller: " + reason);
            return Map.of(
                "success", true,
                "message", "Dispute resolved. Payment released to seller.",
                "status", "RELEASED"
            );
        } else {
            throw new RuntimeException(
                "Invalid action. Use REFUND or RELEASE");
        }
    }

    // ── Audit Logs ────────────────────────────────────────────
    public List<AdminLog> getRecentLogs() {
        return logRepo.findTop50ByOrderByCreatedAtDesc();
    }

    public List<SupportRequest> getSupportRequests(String status) {
        if (status == null || status.isBlank()) {
            return supportRepo.findAllByOrderByCreatedAtDesc();
        }

        try {
            return supportRepo.findByStatusOrderByCreatedAtDesc(
                SupportStatus.valueOf(status.toUpperCase())
            );
        } catch (IllegalArgumentException e) {
            return supportRepo.findAllByOrderByCreatedAtDesc();
        }
    }

    public SupportRequest updateSupportRequestStatus(
        Long adminId,
        Long requestId,
        String status
    ) {
        requireAdmin(adminId);
        SupportRequest request = supportRepo.findById(requestId)
            .orElseThrow(() -> new RuntimeException("Support request not found"));

        SupportStatus nextStatus = SupportStatus.valueOf(status.toUpperCase());
        request.setStatus(nextStatus);
        request.setResolvedAt(nextStatus == SupportStatus.RESOLVED ? LocalDateTime.now() : null);
        SupportRequest saved = supportRepo.save(request);

        log(adminId, "UPDATE_SUPPORT_REQUEST", TargetType.SYSTEM, requestId,
            "Support request marked as " + nextStatus);
        return saved;
    }

    public SiteSetting getSiteSettings(Long adminId) {
        requireAdmin(adminId);
        return siteSettingService.getSettings();
    }

    public SiteSetting updateSiteSettings(Long adminId, Map<String, Object> body) {
        requireAdmin(adminId);
        SiteSetting saved = siteSettingService.updateSettings(body);
        log(adminId, "UPDATE_SITE_SETTINGS", TargetType.SYSTEM, saved.getId(),
            "Updated public company, support, social, and policy settings");
        return saved;
    }

    public Map<String, Object> getInlineItemImageStats(Long adminId) {
        requireAdmin(adminId);
        return legacyItemImageMigrationService.getInlineImageStats();
    }

    public Map<String, Object> migrateInlineItemImages(Long adminId, Integer limit) {
        requireAdmin(adminId);
        Map<String, Object> result = legacyItemImageMigrationService.migrateInlineImages(limit);
        log(adminId, "MIGRATE_INLINE_ITEM_IMAGES", TargetType.SYSTEM, null,
            "Migrated legacy inline item images");
        return result;
    }

    // ── Private: Log Action ───────────────────────────────────
    private void log(Long adminId, String action,
                     TargetType type, Long targetId,
                     String description) {
        try {
            AdminLog entry = new AdminLog();
            Student admin = new Student();
            admin.setId(adminId);
            entry.setAdmin(admin);
            entry.setAction(action);
            entry.setTargetType(type);
            entry.setTargetId(targetId);
            entry.setDescription(description);
            logRepo.save(entry);
        } catch (Exception e) {
            System.err.println("Log failed: " + e.getMessage());
        }
    }

    private long safeCount(java.util.function.Supplier<Long> fn) {
        try { return fn.get(); } catch (Exception e) { return 0L; }
    }

    private java.math.BigDecimal safeAmount(java.util.function.Supplier<java.math.BigDecimal> fn) {
        try { return fn.get(); } catch (Exception e) { return java.math.BigDecimal.ZERO; }
    }

    private double safeResolutionRate(long resolved, long total) {
        if (total == 0) return 0.0;
        return Math.round(((double) resolved / (double) total) * 1000.0) / 10.0;
    }

    private void enrichReport(Report report) {
        if (report == null || report.getItem() == null || report.getItem().getId() == null) {
            return;
        }

        Long itemId = report.getItem().getId();
        report.setItemReportCount(reportRepo.countByItemId(itemId));
        report.setPendingReportCount(reportRepo.countByItemIdAndStatus(itemId, ReportStatus.PENDING));
    }
}
