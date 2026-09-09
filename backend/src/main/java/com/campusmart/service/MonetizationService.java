package com.campusmart.service;

import com.campusmart.model.CommissionLedgerEntry;
import com.campusmart.model.Item;
import com.campusmart.model.PaymentOrder;
import com.campusmart.model.Student;
import com.campusmart.model.SubscriptionRecord;
import com.campusmart.model.CommissionLedgerEntry.EntryType;
import com.campusmart.model.PaymentOrder.PaymentStatus;
import com.campusmart.model.Student.ContactAccessTier;
import com.campusmart.model.Student.StudentRole;
import com.campusmart.model.SubscriptionRecord.PaymentMode;
import com.campusmart.model.SubscriptionRecord.SubscriptionStatus;
import com.campusmart.repository.CommissionLedgerEntryRepository;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.PaymentOrderRepository;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.SubscriptionRecordRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class MonetizationService {

    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

    @Autowired private StudentRepository studentRepository;
    @Autowired private ItemRepository itemRepository;
    @Autowired private PaymentOrderRepository paymentOrderRepository;
    @Autowired private SubscriptionRecordRepository subscriptionRecordRepository;
    @Autowired private CommissionLedgerEntryRepository commissionLedgerEntryRepository;
    @Autowired private StudentService studentService;

    @Value("${app.allow-test-plan-activation:true}")
    private boolean allowTestPlanActivation;

    public List<Map<String, Object>> getPlans() {
        return planSpecs().stream()
            .sorted(Comparator.comparingInt(PlanSpec::sortOrder))
            .map(this::toPlanMap)
            .collect(Collectors.toList());
    }

    public Map<String, Object> getSummary(Long requesterId, Long targetUserId) {
        Student requester = studentRepository.findById(requesterId)
            .orElseThrow(() -> new RuntimeException("Requester not found"));
        Student target = studentRepository.findById(targetUserId)
            .orElseThrow(() -> new RuntimeException("Student not found"));

        boolean sameUser = requester.getId().equals(target.getId());
        boolean adminView = requester.getRole() == StudentRole.ADMIN || requester.getRole() == StudentRole.MODERATOR;
        if (!sameUser && !adminView) {
            throw new RuntimeException("Unauthorized access");
        }

        refreshStudentEntitlements(target);

        Map<String, Object> summary = new LinkedHashMap<>();
        PlanSpec currentPlan = getPlanSpec(target.getActiveSubscriptionCode());
        List<PaymentOrder> sellerOrders = paymentOrderRepository.findBySellerIdOrderByCreatedAtDesc(targetUserId);

        BigDecimal releasedPlatformFees = sumOrdersByStatus(
            sellerOrders,
            List.of(PaymentStatus.RELEASED),
            PaymentOrder::getPlatformFeeAmount
        );
        BigDecimal pendingPlatformFees = sumOrdersByStatus(
            sellerOrders,
            List.of(PaymentStatus.PAID, PaymentStatus.ESCROW_HOLD, PaymentStatus.DISPUTED),
            PaymentOrder::getPlatformFeeAmount
        );
        BigDecimal releasedSellerNet = sumOrdersByStatus(
            sellerOrders,
            List.of(PaymentStatus.RELEASED),
            PaymentOrder::getSellerNetAmount
        );
        BigDecimal pendingSellerNet = sumOrdersByStatus(
            sellerOrders,
            List.of(PaymentStatus.PAID, PaymentStatus.ESCROW_HOLD, PaymentStatus.DISPUTED),
            PaymentOrder::getSellerNetAmount
        );

        summary.put("studentId", target.getId());
        summary.put("activeSubscriptionCode", target.getActiveSubscriptionCode());
        summary.put("contactAccessTier", target.getContactAccessTier());
        summary.put("contactAccessExpiresAt", target.getContactAccessExpiresAt());
        summary.put("subscriptionActivatedAt", target.getSubscriptionActivatedAt());
        summary.put("availableBoostCredits", safeInt(target.getAvailableBoostCredits()));
        summary.put("usedBoostCredits", safeInt(target.getUsedBoostCredits()));
        summary.put("commissionPercent", safeAmount(target.getCurrentCommissionPercent()));
        summary.put("activeBoostedListings", itemRepository.countBySellerIdAndBoostExpiresAtAfter(targetUserId, LocalDateTime.now()));
        summary.put("releasedPlatformFees", releasedPlatformFees);
        summary.put("pendingPlatformFees", pendingPlatformFees);
        summary.put("releasedSellerNet", releasedSellerNet);
        summary.put("pendingSellerNet", pendingSellerNet);
        summary.put("releasedOrders", sellerOrders.stream().filter(order -> order.getStatus() == PaymentStatus.RELEASED).count());
        summary.put("pendingOrders", sellerOrders.stream().filter(order ->
            order.getStatus() == PaymentStatus.PAID
                || order.getStatus() == PaymentStatus.ESCROW_HOLD
                || order.getStatus() == PaymentStatus.DISPUTED
        ).count());
        summary.put("currentPlan", toPlanMap(currentPlan));
        summary.put("plans", getPlans());
        summary.put(
            "recentLedger",
            commissionLedgerEntryRepository.findTop20BySellerIdOrderByCreatedAtDesc(targetUserId).stream()
                .map(this::toLedgerMap)
                .collect(Collectors.toList())
        );
        summary.put(
            "subscriptions",
            subscriptionRecordRepository.findByStudentIdOrderByStartedAtDesc(targetUserId).stream()
                .limit(6)
                .map(this::toSubscriptionMap)
                .collect(Collectors.toList())
        );

        return summary;
    }

    public Map<String, Object> activatePlan(Long studentId, String planCode) {
        Student student = studentRepository.findById(studentId)
            .orElseThrow(() -> new RuntimeException("Student not found"));
        PlanSpec plan = getPlanSpec(planCode);
        refreshStudentEntitlements(student);

        if (!allowTestPlanActivation && plan.price().compareTo(ZERO) > 0) {
            throw new RuntimeException("Test plan activation is disabled");
        }

        if ("FREE".equalsIgnoreCase(plan.code())) {
            resetToFreePlan(student);
            studentRepository.save(student);
            return buildMutationResponse(student, "Free plan restored");
        }

        subscriptionRecordRepository.findTopByStudentIdAndStatusOrderByStartedAtDesc(
            studentId,
            SubscriptionStatus.ACTIVE
        ).ifPresent(existing -> {
            existing.setStatus(SubscriptionStatus.CANCELLED);
            existing.setNotes("Superseded by " + plan.code() + " test activation");
            subscriptionRecordRepository.save(existing);
        });

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expiresAt = now.plusDays(plan.durationDays());

        SubscriptionRecord record = new SubscriptionRecord();
        record.setStudent(student);
        record.setPlanCode(plan.code());
        record.setPlanName(plan.name());
        record.setStatus(SubscriptionStatus.ACTIVE);
        record.setPaymentMode(PaymentMode.TEST);
        record.setAmount(plan.price());
        record.setCommissionPercent(plan.commissionPercent());
        record.setIncludedBoostCredits(plan.boostCredits());
        record.setStartedAt(now);
        record.setExpiresAt(expiresAt);
        record.setNotes("Test activation for sandbox monetization flow");
        subscriptionRecordRepository.save(record);

        student.setActiveSubscriptionCode(plan.code());
        student.setContactAccessTier(plan.contactAccessTier());
        student.setContactAccessExpiresAt(expiresAt);
        student.setSubscriptionActivatedAt(now);
        student.setCurrentCommissionPercent(plan.commissionPercent());
        student.setAvailableBoostCredits(safeInt(student.getAvailableBoostCredits()) + plan.boostCredits());
        studentRepository.save(student);

        return buildMutationResponse(student, plan.name() + " plan activated in test mode");
    }

    public Map<String, Object> boostListing(Long sellerId, Long itemId) {
        Student seller = studentRepository.findById(sellerId)
            .orElseThrow(() -> new RuntimeException("Seller not found"));
        Item item = itemRepository.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found"));

        refreshStudentEntitlements(seller);

        if (item.getSeller() == null || !sellerId.equals(item.getSeller().getId())) {
            throw new RuntimeException("You can boost only your own listings");
        }
        if (item.getStatus() != Item.ItemStatus.AVAILABLE) {
            throw new RuntimeException("Only active listings can be boosted");
        }
        if (isBoostActive(item)) {
            throw new RuntimeException("This listing is already boosted");
        }
        if (safeInt(seller.getAvailableBoostCredits()) <= 0) {
            throw new RuntimeException("No boost credits left. Activate a paid plan first.");
        }

        PlanSpec plan = getPlanSpec(seller.getActiveSubscriptionCode());
        LocalDateTime now = LocalDateTime.now();
        item.setBoostLevel(plan.boostLevel());
        item.setBoostedAt(now);
        item.setBoostExpiresAt(now.plusDays(plan.boostDurationDays()));
        item.setBoostActive(true);
        itemRepository.save(item);

        seller.setAvailableBoostCredits(safeInt(seller.getAvailableBoostCredits()) - 1);
        seller.setUsedBoostCredits(safeInt(seller.getUsedBoostCredits()) + 1);
        studentRepository.save(seller);

        Map<String, Object> result = buildMutationResponse(seller, "Listing boosted successfully");
        result.put("item", item);
        return result;
    }

    public BigDecimal getCommissionPercentForSeller(Student seller) {
        if (seller == null) {
            return getPlanSpec("FREE").commissionPercent();
        }
        refreshStudentEntitlements(seller);
        return safeAmount(
            seller.getCurrentCommissionPercent() != null
                ? seller.getCurrentCommissionPercent()
                : getPlanSpec(seller.getActiveSubscriptionCode()).commissionPercent()
        );
    }

    public void applyFeeBreakdown(PaymentOrder order, Student seller) {
        BigDecimal amount = safeAmount(order.getAmount());
        BigDecimal feePercent = getCommissionPercentForSeller(seller);
        BigDecimal platformFee = amount
            .multiply(feePercent)
            .divide(HUNDRED, 2, RoundingMode.HALF_UP);
        BigDecimal sellerNet = amount.subtract(platformFee).max(ZERO);

        order.setPlatformFeePercent(feePercent);
        order.setPlatformFeeAmount(platformFee);
        order.setSellerNetAmount(sellerNet);
        order.setSellerSubscriptionCode(
            seller != null && seller.getActiveSubscriptionCode() != null
                ? seller.getActiveSubscriptionCode()
                : "FREE"
        );
    }

    public void recordCommissionEvent(PaymentOrder order, EntryType entryType, String notes) {
        if (order == null || order.getSeller() == null || order.getBuyer() == null || order.getItem() == null) {
            return;
        }

        CommissionLedgerEntry entry = new CommissionLedgerEntry();
        entry.setOrder(order);
        entry.setSeller(order.getSeller());
        entry.setBuyer(order.getBuyer());
        entry.setItem(order.getItem());
        entry.setEntryType(entryType);
        entry.setGrossAmount(safeAmount(order.getAmount()));
        entry.setFeePercent(safeAmount(order.getPlatformFeePercent()));
        entry.setPlatformFeeAmount(safeAmount(order.getPlatformFeeAmount()));
        entry.setSellerNetAmount(safeAmount(order.getSellerNetAmount()));
        entry.setNotes(notes);
        commissionLedgerEntryRepository.save(entry);
    }

    public void refreshStudentEntitlements(Student student) {
        if (student == null || student.getId() == null) {
            return;
        }

        Optional<SubscriptionRecord> activeRecordOpt = subscriptionRecordRepository
            .findTopByStudentIdAndStatusOrderByStartedAtDesc(student.getId(), SubscriptionStatus.ACTIVE);
        if (activeRecordOpt.isEmpty()) {
            if (!"FREE".equalsIgnoreCase(student.getActiveSubscriptionCode())
                && student.getContactAccessExpiresAt() != null
                && student.getContactAccessExpiresAt().isBefore(LocalDateTime.now())) {
                resetToFreePlan(student);
                studentRepository.save(student);
            }
            return;
        }

        SubscriptionRecord activeRecord = activeRecordOpt.get();
        if (activeRecord.getExpiresAt() != null && !activeRecord.getExpiresAt().isAfter(LocalDateTime.now())) {
            activeRecord.setStatus(SubscriptionStatus.EXPIRED);
            activeRecord.setNotes("Subscription expired automatically");
            subscriptionRecordRepository.save(activeRecord);
            resetToFreePlan(student);
            studentRepository.save(student);
            return;
        }

        PlanSpec plan = getPlanSpec(activeRecord.getPlanCode());
        boolean changed = false;

        if (!plan.code().equalsIgnoreCase(student.getActiveSubscriptionCode())) {
            student.setActiveSubscriptionCode(plan.code());
            changed = true;
        }
        if (student.getContactAccessTier() != plan.contactAccessTier()) {
            student.setContactAccessTier(plan.contactAccessTier());
            changed = true;
        }
        if (!safeAmount(student.getCurrentCommissionPercent()).equals(plan.commissionPercent())) {
            student.setCurrentCommissionPercent(plan.commissionPercent());
            changed = true;
        }
        if (student.getContactAccessExpiresAt() == null
            || !student.getContactAccessExpiresAt().equals(activeRecord.getExpiresAt())) {
            student.setContactAccessExpiresAt(activeRecord.getExpiresAt());
            changed = true;
        }

        if (changed) {
            studentRepository.save(student);
        }
    }

    public boolean isBoostActive(Item item) {
        return item != null
            && item.getBoostExpiresAt() != null
            && item.getBoostExpiresAt().isAfter(LocalDateTime.now())
            && safeInt(item.getBoostLevel()) > 0;
    }

    private Map<String, Object> buildMutationResponse(Student student, String message) {
        studentService.prepareStudentForViewer(student, student);
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("message", message);
        response.put("student", student);
        response.put("summary", getSummary(student.getId(), student.getId()));
        return response;
    }

    private void resetToFreePlan(Student student) {
        PlanSpec freePlan = getPlanSpec("FREE");
        student.setActiveSubscriptionCode(freePlan.code());
        student.setContactAccessTier(ContactAccessTier.FREE);
        student.setContactAccessExpiresAt(null);
        student.setSubscriptionActivatedAt(null);
        student.setAvailableBoostCredits(0);
        student.setCurrentCommissionPercent(freePlan.commissionPercent());
    }

    private List<PlanSpec> planSpecs() {
        List<PlanSpec> plans = new ArrayList<>();
        plans.add(new PlanSpec(
            "FREE", "Free", "Safe chat-first access for early users", ZERO,
            0, BigDecimal.valueOf(7.00), 0, ContactAccessTier.FREE, 0, 0, 0,
            "Starter", List.of("In-app chat", "Standard 7% seller fee", "No direct-contact unlock")
        ));
        plans.add(new PlanSpec(
            "PLUS", "Plus", "Lower seller fee and a few boost credits", BigDecimal.valueOf(199.00),
            30, BigDecimal.valueOf(6.00), 3, ContactAccessTier.PLUS, 1, 7, 1,
            "Best for steady sellers", List.of("Direct seller contact access", "3 boost credits", "6% seller fee")
        ));
        plans.add(new PlanSpec(
            "PREMIUM", "Premium", "Best monetization plan for active campus sellers", BigDecimal.valueOf(499.00),
            90, BigDecimal.valueOf(5.00), 10, ContactAccessTier.PREMIUM, 2, 10, 2,
            "Launch-ready seller mode", List.of("Priority contact reveal", "10 boost credits", "5% seller fee")
        ));
        return plans;
    }

    private PlanSpec getPlanSpec(String code) {
        return planSpecs().stream()
            .filter(plan -> plan.code().equalsIgnoreCase(code == null ? "FREE" : code))
            .findFirst()
            .orElse(planSpecs().get(0));
    }

    private Map<String, Object> toPlanMap(PlanSpec plan) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("code", plan.code());
        map.put("name", plan.name());
        map.put("description", plan.description());
        map.put("price", plan.price());
        map.put("durationDays", plan.durationDays());
        map.put("commissionPercent", plan.commissionPercent());
        map.put("boostCredits", plan.boostCredits());
        map.put("contactAccessTier", plan.contactAccessTier());
        map.put("boostLevel", plan.boostLevel());
        map.put("boostDurationDays", plan.boostDurationDays());
        map.put("highlight", plan.highlight());
        map.put("features", plan.features());
        map.put("testMode", true);
        return map;
    }

    private Map<String, Object> toSubscriptionMap(SubscriptionRecord record) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", record.getId());
        map.put("planCode", record.getPlanCode());
        map.put("planName", record.getPlanName());
        map.put("status", record.getStatus());
        map.put("paymentMode", record.getPaymentMode());
        map.put("amount", record.getAmount());
        map.put("commissionPercent", record.getCommissionPercent());
        map.put("includedBoostCredits", record.getIncludedBoostCredits());
        map.put("startedAt", record.getStartedAt());
        map.put("expiresAt", record.getExpiresAt());
        map.put("notes", record.getNotes());
        return map;
    }

    private Map<String, Object> toLedgerMap(CommissionLedgerEntry entry) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", entry.getId());
        map.put("entryType", entry.getEntryType());
        map.put("grossAmount", entry.getGrossAmount());
        map.put("feePercent", entry.getFeePercent());
        map.put("platformFeeAmount", entry.getPlatformFeeAmount());
        map.put("sellerNetAmount", entry.getSellerNetAmount());
        map.put("createdAt", entry.getCreatedAt());
        map.put("notes", entry.getNotes());
        map.put("orderId", entry.getOrder() != null ? entry.getOrder().getId() : null);
        map.put("itemTitle", entry.getItem() != null ? entry.getItem().getTitle() : null);
        return map;
    }

    private BigDecimal sumOrdersByStatus(
        List<PaymentOrder> orders,
        List<PaymentStatus> statuses,
        java.util.function.Function<PaymentOrder, BigDecimal> extractor
    ) {
        return orders.stream()
            .filter(order -> statuses.contains(order.getStatus()))
            .map(extractor)
            .filter(value -> value != null)
            .reduce(ZERO, BigDecimal::add);
    }

    private int safeInt(Integer value) {
        return value == null ? 0 : value;
    }

    private BigDecimal safeAmount(BigDecimal value) {
        return value == null ? ZERO : value.setScale(2, RoundingMode.HALF_UP);
    }

    private record PlanSpec(
        String code,
        String name,
        String description,
        BigDecimal price,
        int durationDays,
        BigDecimal commissionPercent,
        int boostCredits,
        ContactAccessTier contactAccessTier,
        int boostLevel,
        int boostDurationDays,
        int sortOrder,
        String highlight,
        List<String> features
    ) {
    }
}
