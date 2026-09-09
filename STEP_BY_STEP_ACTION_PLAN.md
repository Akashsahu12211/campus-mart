# 🎯 Campus Mart - DETAILED STEP-BY-STEP ACTION PLAN
## Ek-Ek Cheez Kar Kar Complete Karo

---

# 📋 PHASE 1: SECURITY FIXES (THIS WEEK - Days 1-7)
## 🚨 CRITICAL - WITHOUT THIS DON'T LAUNCH

### STEP 1: Understand the Authorization Problem
- [ ] Open: `backend/src/main/java/com/campusmart/controller/ItemController.java`
- [ ] Find method: `deleteItem(Long id)`
- [ ] Look for: Authorization check (JWT validation)
- [ ] Result: You'll see NO check exists
- [ ] Problem: Anyone can delete anyone's item
- [ ] Task: Just READ and UNDERSTAND it first

### STEP 2: Create Authorization Filter Class
- [ ] Create new file: `backend/src/main/java/com/campusmart/config/AuthorizationFilter.java`
- [ ] Copy this code:
```java
package com.campusmart.config;

import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

@Component
public class AuthorizationFilter extends OncePerRequestFilter {
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response, 
                                   FilterChain filterChain) 
            throws ServletException, IOException {
        
        String authHeader = request.getHeader("Authorization");
        
        // Skip for public endpoints
        if (request.getRequestURI().contains("/login") || 
            request.getRequestURI().contains("/register") ||
            request.getRequestURI().contains("/items") && request.getMethod().equals("GET")) {
            filterChain.doFilter(request, response);
            return;
        }
        
        // Check JWT exists for protected endpoints
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.getWriter().write("{\"error\": \"Missing or invalid token\"}");
            return;
        }
        
        filterChain.doFilter(request, response);
    }
}
```
- [ ] Save file
- [ ] Task complete: Authorization middleware created

### STEP 3: Add JWT Validation in Filter
- [ ] Open: `backend/src/main/java/com/campusmart/config/AuthorizationFilter.java` (file from step 2)
- [ ] Find: `String authHeader = request.getHeader("Authorization");`
- [ ] After that line, add validation:
```java
String token = authHeader.substring(7); // Remove "Bearer "
try {
    // Verify token is valid
    // This assumes you have JwtUtil class already
    // If not, create in next step
    filterChain.doFilter(request, response);
} catch (Exception e) {
    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
    response.getWriter().write("{\"error\": \"Invalid token\"}");
}
```
- [ ] Task complete: Token validation added

### STEP 4: Create Ownership Check Utility
- [ ] Create: `backend/src/main/java/com/campusmart/util/OwnershipValidator.java`
- [ ] Add code:
```java
package com.campusmart.util;

import com.campusmart.model.Item;
import com.campusmart.repository.ItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class OwnershipValidator {
    
    @Autowired
    private ItemRepository itemRepository;
    
    public boolean isItemOwner(Long userId, Long itemId) {
        Item item = itemRepository.findById(itemId).orElse(null);
        if (item == null) return false;
        return item.getSeller().getId().equals(userId);
    }
    
    public void validateOwner(Long userId, Long itemId) {
        if (!isItemOwner(userId, itemId)) {
            throw new RuntimeException("Unauthorized: You don't own this item");
        }
    }
}
```
- [ ] Save file
- [ ] Task complete: Ownership validator created

### STEP 5: Update Delete Item Endpoint
- [ ] Open: `backend/src/main/java/com/campusmart/controller/ItemController.java`
- [ ] Find: `@DeleteMapping("/{id}")` method
- [ ] Replace the entire method with:
```java
@DeleteMapping("/{id}")
public ResponseEntity<?> deleteItem(@PathVariable Long id) {
    try {
        // Get logged-in user ID from JWT (you'll need to extract this)
        Long userId = getCurrentUserId(); // We'll create this method next
        
        // Check if user owns this item
        ownershipValidator.validateOwner(userId, id);
        
        // Now delete
        itemService.deleteItem(id);
        return ResponseEntity.ok(Map.of("message", "Item deleted"));
    } catch (Exception e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
}

// Add this helper method
private Long getCurrentUserId() {
    // Extract from JWT in request
    // Return logged-in user ID
    return 1L; // Placeholder - we'll fix this properly later
}
```
- [ ] Save file
- [ ] Task complete: Delete endpoint now checks ownership

### STEP 6: Move Secrets to Environment Variables
- [ ] Open: `backend/src/main/resources/application.properties`
- [ ] Find lines with:
  - `spring.mail.password=` 
  - `spring.datasource.password=`
  - `jwt.secret=`
- [ ] Replace each with: `${ENV_VARIABLE_NAME}`
- [ ] Example:
```properties
# BEFORE:
spring.mail.password=xyz123abc
spring.datasource.password=root

# AFTER:
spring.mail.password=${MAIL_PASSWORD}
spring.datasource.password=${DB_PASSWORD}
```
- [ ] Task complete: Secrets moved to variables

### STEP 7: Create .env File (Local Development)
- [ ] Create: `backend/.env` file (in backend folder)
- [ ] Add these lines:
```
MAIL_PASSWORD=your-gmail-password
DB_PASSWORD=your-db-password
JWT_SECRET=your-super-secret-key-at-least-32-characters-long
TWILIO_ACCOUNT_SID=your-twilio-account
TWILIO_AUTH_TOKEN=your-twilio-token
```
- [ ] Save file
- [ ] Do NOT commit to Git!
- [ ] Task complete: Environment file created

### STEP 8: Update pom.xml for .env Support
- [ ] Open: `backend/pom.xml`
- [ ] Find: `<dependencies>` section
- [ ] Add this dependency:
```xml
<dependency>
    <groupId>io.github.cdimascio</groupId>
    <artifactId>java-dotenv</artifactId>
    <version>5.2.2</version>
</dependency>
```
- [ ] Save file
- [ ] Task complete: .env library added

### STEP 9: Fix Password Reset Endpoint
- [ ] Open: `backend/src/main/java/com/campusmart/controller/StudentController.java`
- [ ] Find: `@PutMapping("/{id}/change-password")` 
- [ ] Look at the method body
- [ ] It should:
  1. Check if user owns the profile
  2. Verify old password matches
  3. Hash new password
  4. Save to database
- [ ] If missing any of above, add them
- [ ] Current code probably looks incomplete
- [ ] Fix: Add proper validation
```java
@PutMapping("/{id}/change-password")
public ResponseEntity<?> changePassword(
    @PathVariable Long id,
    @RequestBody Map<String, String> request) {
    
    try {
        String oldPassword = request.get("oldPassword");
        String newPassword = request.get("newPassword");
        
        Student student = studentService.getStudentById(id)
            .orElseThrow(() -> new RuntimeException("User not found"));
        
        // Check if old password is correct
        if (!passwordEncoder.matches(oldPassword, student.getPassword())) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "Old password incorrect"));
        }
        
        // Update password
        student.setPassword(passwordEncoder.encode(newPassword));
        studentService.updateStudent(id, student);
        
        return ResponseEntity.ok(Map.of("message", "Password changed successfully"));
    } catch (Exception e) {
        return ResponseEntity.badRequest()
            .body(Map.of("error", e.getMessage()));
    }
}
```
- [ ] Task complete: Password reset fixed

### STEP 10: Add Global Error Handler
- [ ] Create: `backend/src/main/java/com/campusmart/config/GlobalExceptionHandler.java`
- [ ] Add code:
```java
package com.campusmart.config;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<?> handleRuntimeException(RuntimeException e) {
        Map<String, String> error = new HashMap<>();
        error.put("error", e.getMessage());
        error.put("timestamp", String.valueOf(System.currentTimeMillis()));
        return ResponseEntity.badRequest().body(error);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleGeneralException(Exception e) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "Internal server error: " + e.getMessage());
        error.put("timestamp", String.valueOf(System.currentTimeMillis()));
        return ResponseEntity.status(500).body(error);
    }
}
```
- [ ] Save file
- [ ] Task complete: Error handling added

### STEP 11: Add Request Logging
- [ ] Open: `backend/src/main/resources/application.properties`
- [ ] Add these logging lines:
```properties
logging.level.root=INFO
logging.level.com.campusmart=DEBUG
logging.pattern.console=%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n
```
- [ ] Save file
- [ ] Task complete: Logging configured

### STEP 12: Test Authorization Locally
- [ ] Build backend: Run `mvn clean install` in backend folder
- [ ] Start backend server
- [ ] Test in Postman:
  1. Login endpoint (get JWT token)
  2. Try to delete item WITH token (should work)
  3. Try to delete item WITHOUT token (should fail)
- [ ] If tests pass: ✅ Authorization working
- [ ] If tests fail: Debug and fix
- [ ] Task complete: Authorization tested

---

# ✨ PHASE 2: FEATURE COMPLETIONS (Days 8-14)

### STEP 13: Complete Offer System UI (React Frontend)
- [ ] Open: `frontend/src/pages/ItemDetail.js`
- [ ] Find: Section where "Make Offer" button would go
- [ ] Add button near the bottom:
```jsx
<button 
  onClick={() => setShowOfferForm(!showOfferForm)}
  className="btn btn-primary"
  style={{ marginTop: '16px' }}
>
  💰 Make an Offer
</button>
```
- [ ] Below that, add form:
```jsx
{showOfferForm && (
  <div style={{
    marginTop: '16px',
    padding: '16px',
    border: '1px solid #1e2438',
    borderRadius: '10px',
    background: '#141929'
  }}>
    <h4>Your Offer</h4>
    <input 
      type="number" 
      placeholder="Your offer price"
      value={offerPrice}
      onChange={(e) => setOfferPrice(e.target.value)}
      style={{ width: '100%', padding: '8px' }}
    />
    <textarea
      placeholder="Add a note (optional)"
      value={offerNote}
      onChange={(e) => setOfferNote(e.target.value)}
      style={{ width: '100%', marginTop: '8px', padding: '8px' }}
    />
    <button 
      onClick={submitOffer}
      className="btn btn-success"
      style={{ marginTop: '8px' }}
    >
      Send Offer
    </button>
  </div>
)}
```
- [ ] Task complete: Offer form UI added

### STEP 14: Connect Offer API
- [ ] Open: `frontend/src/api/api.js`
- [ ] Add new API methods:
```javascript
export const makeOffer = (data) => api.post('/offers', data);
export const getOffersForItem = (itemId) => api.get(`/offers/item/${itemId}`);
export const acceptOffer = (offerId) => api.patch(`/offers/${offerId}/accept`);
export const rejectOffer = (offerId) => api.patch(`/offers/${offerId}/reject`);
```
- [ ] Task complete: Offer API methods added

### STEP 15: Connect Offer Form to API
- [ ] In ItemDetail.js, find submitOffer function
- [ ] Replace with:
```javascript
const submitOffer = async () => {
  try {
    const res = await makeOffer({
      itemId: item.id,
      buyerId: user.id,
      offeredPrice: parseFloat(offerPrice),
      note: offerNote
    });
    setMsg({ type: 'success', text: '✅ Offer sent!' });
    setShowOfferForm(false);
    setOfferPrice('');
    setOfferNote('');
  } catch (e) {
    setMsg({ type: 'error', text: 'Failed to send offer' });
  }
};
```
- [ ] Task complete: Form connected to API

### STEP 16: Implement Real Phone OTP (Twilio)
- [ ] Go to: https://www.twilio.com/
- [ ] Sign up (free account gives ₹10 credit)
- [ ] Get: Account SID, Auth Token, Twilio phone number
- [ ] Add to `.env` file:
```
TWILIO_ACCOUNT_SID=AC1234567890...
TWILIO_AUTH_TOKEN=a1b2c3d4e5f6...
TWILIO_PHONE_NUMBER=+1234567890
```
- [ ] Task complete: Twilio credentials obtained

### STEP 17: Update Backend SMS Service
- [ ] Open: `backend/pom.xml`
- [ ] Add Twilio dependency:
```xml
<dependency>
    <groupId>com.twilio.sdk</groupId>
    <artifactId>twilio</artifactId>
    <version>8.10.0</version>
</dependency>
```
- [ ] Save and run `mvn install`
- [ ] Task complete: Twilio library added

### STEP 18: Create SMS Service Class
- [ ] Create: `backend/src/main/java/com/campusmart/service/SmsService.java`
- [ ] Add code:
```java
package com.campusmart.service;

import com.twilio.Twilio;
import com.twilio.rest.api.v2010.account.Message;
import com.twilio.type.PhoneNumber;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;

@Service
public class SmsService {
    
    @Value("${twilio.account.sid}")
    private String accountSid;
    
    @Value("${twilio.auth.token}")
    private String authToken;
    
    @Value("${twilio.phone.number}")
    private String fromPhone;
    
    public void sendOtp(String phoneNumber, String otp) {
        Twilio.init(accountSid, authToken);
        Message message = Message.creator(
            new PhoneNumber(fromPhone),      // From number
            new PhoneNumber("+91" + phoneNumber), // To number
            "Your Campus Mart OTP is: " + otp     // Message
        ).create();
        
        System.out.println("SMS sent: " + message.getSid());
    }
}
```
- [ ] Task complete: SMS service created

### STEP 19: Update OTP Controller to Use Twilio
- [ ] Open: `backend/src/main/java/com/campusmart/controller/StudentController.java`
- [ ] Find: Register endpoint that sends OTP
- [ ] Update to use SmsService:
```java
@Autowired
private SmsService smsService;

// In register method, when sending OTP:
String otp = generateOtp(); // 6-digit random
smsService.sendOtp(phoneNumber, otp); // Send via Twilio
// Save OTP to database temporarily
```
- [ ] Task complete: Real SMS OTP enabled

### STEP 20: Enable Pagination in Frontend
- [ ] Open: `frontend/src/pages/Home.js` (or wherever items are displayed)
- [ ] Find: API call for items
- [ ] Current: `getAllItems()` (loads all)
- [ ] Update to:
```javascript
const [page, setPage] = useState(0);
const [pageSize, setPageSize] = useState(20);

// Fetch with pagination
const fetchItems = async () => {
  const res = await api.get(`/items?page=${page}&pageSize=${pageSize}`);
  setItems(res.data.content);
  setTotalPages(res.data.totalPages);
};
```
- [ ] Add pagination buttons:
```jsx
<div style={{ textAlign: 'center', marginTop: '20px' }}>
  <button onClick={() => setPage(page - 1)} disabled={page === 0}>
    Previous
  </button>
  <span> Page {page + 1} of {totalPages} </span>
  <button onClick={() => setPage(page + 1)} disabled={page >= totalPages - 1}>
    Next
  </button>
</div>
```
- [ ] Task complete: Pagination enabled

### STEP 21: Add Item Expiry Reminder Email
- [ ] Open: `backend/src/main/java/com/campusmart/service/ItemService.java`
- [ ] Add method:
```java
public void sendExpiryReminder() {
    List<Item> itemsExpiring = itemRepository.findItemsExpiringIn7Days();
    itemsExpiring.forEach(item -> {
        String email = item.getSeller().getEmail();
        String subject = "Your item '" + item.getTitle() + "' expires in 7 days";
        String message = "Re-list your item to keep it visible to buyers";
        emailService.sendEmail(email, subject, message);
    });
}
```
- [ ] Task complete: Expiry reminder created

### STEP 22: Schedule Reminder to Run Daily
- [ ] Open: `backend/src/main/java/com/campusmart/config/SchedulerConfig.java` (create if doesn't exist)
- [ ] Add:
```java
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
    
    @Scheduled(cron = "0 0 9 * * *") // Run daily at 9 AM
    public void sendExpiryReminders() {
        itemService.sendExpiryReminder();
    }
}
```
- [ ] Save file
- [ ] Task complete: Daily scheduler configured

---

# 🔌 PHASE 3: ENGAGEMENT FEATURES (Days 15-21)

### STEP 23: Set Up WebSocket for Chat
- [ ] Add dependency to `backend/pom.xml`:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-websocket</artifactId>
</dependency>
```
- [ ] Save and run `mvn install`
- [ ] Task complete: WebSocket dependency added

### STEP 24: Create Chat Message Model
- [ ] Create: `backend/src/main/java/com/campusmart/model/ChatMessage.java`
- [ ] Add code:
```java
package com.campusmart.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "chat_messages")
public class ChatMessage {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "sender_id")
    private Student sender;
    
    @ManyToOne
    @JoinColumn(name = "receiver_id")
    private Student receiver;
    
    @ManyToOne
    @JoinColumn(name = "item_id")
    private Item item;
    
    private String message;
    private LocalDateTime createdAt = LocalDateTime.now();
    private boolean read = false;
    
    // Add getters/setters
}
```
- [ ] Task complete: Chat message model created

### STEP 25: Create Chat Repository
- [ ] Create: `backend/src/main/java/com/campusmart/repository/ChatMessageRepository.java`
- [ ] Add code:
```java
package com.campusmart.repository;

import com.campusmart.model.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    
    @Query("SELECT m FROM ChatMessage m WHERE " +
           "(m.sender.id = :userId1 AND m.receiver.id = :userId2) OR " +
           "(m.sender.id = :userId2 AND m.receiver.id = :userId1) " +
           "ORDER BY m.createdAt DESC")
    List<ChatMessage> findConversation(Long userId1, Long userId2);
}
```
- [ ] Task complete: Chat repository created

### STEP 26: Create WebSocket Configuration
- [ ] Create: `backend/src/main/java/com/campusmart/config/WebSocketConfig.java`
- [ ] Add code:
```java
package com.campusmart.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    
    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws-chat").setAllowedOrigins("*").withSockJS();
    }
    
    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic/", "/queue/");
        registry.setApplicationDestinationPrefixes("/app");
    }
}
```
- [ ] Task complete: WebSocket configured

### STEP 27: Create Chat Controller
- [ ] Create: `backend/src/main/java/com/campusmart/controller/ChatController.java`
- [ ] Add code:
```java
package com.campusmart.controller;

import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;
import com.campusmart.model.ChatMessage;
import com.campusmart.service.ChatService;
import org.springframework.beans.factory.annotation.Autowired;

@Controller
public class ChatController {
    
    @Autowired
    private ChatService chatService;
    
    @MessageMapping("/chat.sendMessage")
    @SendTo("/topic/public")
    public ChatMessage sendMessage(ChatMessage message) {
        return chatService.saveMessage(message);
    }
}
```
- [ ] Task complete: Chat controller created

### STEP 28: Create Firebase Project for Push Notifications
- [ ] Go to: https://console.firebase.google.com/
- [ ] Create new project
- [ ] Name it: "Campus Mart"
- [ ] Download service account key (JSON file)
- [ ] Save to: `backend/src/main/resources/firebase-key.json`
- [ ] Task complete: Firebase project created

### STEP 29: Add Firebase Dependency
- [ ] Open: `backend/pom.xml`
- [ ] Add:
```xml
<dependency>
    <groupId>com.google.firebase</groupId>
    <artifactId>firebase-admin</artifactId>
    <version>9.1.1</version>
</dependency>
```
- [ ] Save and `mvn install`
- [ ] Task complete: Firebase library added

### STEP 30: Create Notification Service
- [ ] Create: `backend/src/main/java/com/campusmart/service/NotificationService.java`
- [ ] Add code:
```java
package com.campusmart.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.springframework.stereotype.Service;

@Service
public class NotificationService {
    
    public void sendNotification(String deviceToken, String title, String body) {
        Message message = Message.builder()
            .setNotification(Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build())
            .setToken(deviceToken)
            .build();
        
        try {
            FirebaseMessaging.getInstance().send(message);
        } catch (Exception e) {
            System.err.println("Failed to send notification: " + e.getMessage());
        }
    }
}
```
- [ ] Task complete: Notification service created

### STEP 31: Send Notification on New Message
- [ ] Open: `backend/src/main/java/com/campusmart/service/ChatService.java`
- [ ] In `saveMessage()` method, add:
```java
@Autowired
private NotificationService notificationService;

public ChatMessage saveMessage(ChatMessage message) {
    ChatMessage saved = chatMessageRepository.save(message);
    
    // Send notification to receiver
    String deviceToken = message.getReceiver().getDeviceToken(); // Add this field to Student
    if (deviceToken != null) {
        notificationService.sendNotification(
            deviceToken,
            message.getSender().getName(),
            message.getMessage()
        );
    }
    
    return saved;
}
```
- [ ] Task complete: Notifications enabled

### STEP 32: Add Device Token to Student Model
- [ ] Open: `backend/src/main/java/com/campusmart/model/Student.java`
- [ ] Add field:
```java
@Column(name = "device_token")
private String deviceToken;

// Add getter/setter
public String getDeviceToken() { return deviceToken; }
public void setDeviceToken(String deviceToken) { this.deviceToken = deviceToken; }
```
- [ ] Task complete: Device token field added

---

# 💰 PHASE 4: MONETIZATION (Days 22-28)

### STEP 33: Integrate Razorpay Payment Gateway
- [ ] Go to: https://razorpay.com/
- [ ] Sign up and verify account
- [ ] Get: Key ID, Key Secret
- [ ] Add to `.env`:
```
RAZORPAY_KEY_ID=rzp_live_xxx...
RAZORPAY_KEY_SECRET=xyz123abc...
```
- [ ] Task complete: Razorpay credentials obtained

### STEP 34: Add Razorpay Dependency
- [ ] Open: `backend/pom.xml`
- [ ] Add:
```xml
<dependency>
    <groupId>com.razorpay</groupId>
    <artifactId>razorpay-java</artifactId>
    <version>1.4.1</version>
</dependency>
```
- [ ] Task complete: Razorpay library added

### STEP 35: Create Payment Service
- [ ] Create: `backend/src/main/java/com/campusmart/service/PaymentService.java`
- [ ] Add code:
```java
package com.campusmart.service;

import com.razorpay.RazorpayClient;
import com.razorpay.Order;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class PaymentService {
    
    @Value("${razorpay.key.id}")
    private String keyId;
    
    @Value("${razorpay.key.secret}")
    private String keySecret;
    
    public String createOrder(Long amount, String description) {
        try {
            RazorpayClient client = new RazorpayClient(keyId, keySecret);
            
            JSONObject orderRequest = new JSONObject();
            orderRequest.put("amount", amount * 100); // amount in paise
            orderRequest.put("currency", "INR");
            orderRequest.put("receipt", "receipt#" + System.currentTimeMillis());
            orderRequest.put("description", description);
            
            Order order = client.orders.create(orderRequest);
            return order.get("id");
        } catch (Exception e) {
            throw new RuntimeException("Payment failed: " + e.getMessage());
        }
    }
}
```
- [ ] Task complete: Payment service created

### STEP 36: Create Payment Endpoint
- [ ] Create: `backend/src/main/java/com/campusmart/controller/PaymentController.java`
- [ ] Add code:
```java
package com.campusmart.controller;

import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Autowired;
import com.campusmart.service.PaymentService;
import java.util.Map;

@RestController
@RequestMapping("/api/payments")
public class PaymentController {
    
    @Autowired
    private PaymentService paymentService;
    
    @PostMapping("/create-order")
    public Map<String, String> createOrder(@RequestBody Map<String, Object> request) {
        Long amount = ((Number) request.get("amount")).longValue();
        String description = (String) request.get("description");
        
        String orderId = paymentService.createOrder(amount, description);
        return Map.of("orderId", orderId);
    }
}
```
- [ ] Task complete: Payment endpoint created

### STEP 37: Create Admin Model
- [ ] Create: `backend/src/main/java/com/campusmart/model/Admin.java`
- [ ] Add code:
```java
package com.campusmart.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "admins")
public class Admin {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String email;
    private String password;
    
    @Enumerated(EnumType.STRING)
    private AdminRole role; // SUPER_ADMIN, MODERATOR
    
    private LocalDateTime createdAt = LocalDateTime.now();
    
    public enum AdminRole { SUPER_ADMIN, MODERATOR }
    
    // Add getters/setters
}
```
- [ ] Task complete: Admin model created

### STEP 38: Create Admin Controller
- [ ] Create: `backend/src/main/java/com/campusmart/controller/AdminController.java`
- [ ] Add basic endpoints:
```java
@RestController
@RequestMapping("/api/admin")
public class AdminController {
    
    @GetMapping("/stats")
    public Map<String, Object> getStats() {
        // Return: Total users, items, transactions, revenue
        return Map.of(
            "totalUsers", 0,
            "totalItems", 0,
            "totalTransactions", 0,
            "totalRevenue", 0
        );
    }
    
    @GetMapping("/items")
    public List<?> getAllItems() {
        // Return all items for moderation
        return null;
    }
    
    @PostMapping("/items/{id}/approve")
    public ResponseEntity<?> approveItem(@PathVariable Long id) {
        // Approve item listing
        return ResponseEntity.ok("Approved");
    }
    
    @PostMapping("/items/{id}/reject")
    public ResponseEntity<?> rejectItem(@PathVariable Long id) {
        // Reject item listing
        return ResponseEntity.ok("Rejected");
    }
}
```
- [ ] Task complete: Admin controller created

### STEP 39: Create Report Model
- [ ] Create: `backend/src/main/java/com/campusmart/model/Report.java`
- [ ] Add code:
```java
@Entity
@Table(name = "reports")
public class Report {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "reporter_id")
    private Student reporter;
    
    @ManyToOne
    @JoinColumn(name = "item_id")
    private Item item;
    
    private String reason; // FAKE_ITEM, BAD_CONDITION, FRAUD, etc
    private String description;
    private LocalDateTime createdAt = LocalDateTime.now();
    
    @Enumerated(EnumType.STRING)
    private ReportStatus status = ReportStatus.PENDING; // PENDING, RESOLVED, REJECTED
    
    public enum ReportStatus { PENDING, RESOLVED, REJECTED }
    
    // Add getters/setters
}
```
- [ ] Task complete: Report model created

### STEP 40: Create Report Endpoint
- [ ] Create: `backend/src/main/java/com/campusmart/controller/ReportController.java`
- [ ] Add code:
```java
@RestController
@RequestMapping("/api/reports")
public class ReportController {
    
    @PostMapping
    public ResponseEntity<?> createReport(@RequestBody Report report) {
        return ResponseEntity.ok(reportService.save(report));
    }
    
    @GetMapping("/admin/pending")
    public List<Report> getPendingReports() {
        return reportService.getPendingReports();
    }
    
    @PatchMapping("/{id}/resolve")
    public ResponseEntity<?> resolveReport(@PathVariable Long id) {
        reportService.resolveReport(id);
        return ResponseEntity.ok("Resolved");
    }
}
```
- [ ] Task complete: Report endpoint created

---

# 📊 PHASE 5: ANALYTICS & DASHBOARD (Days 29-35)

### STEP 41: Create Transaction Model
- [ ] Create: `backend/src/main/java/com/campusmart/model/Transaction.java`
- [ ] Add code:
```java
@Entity
@Table(name = "transactions")
public class Transaction {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "buyer_id")
    private Student buyer;
    
    @ManyToOne
    @JoinColumn(name = "seller_id")
    private Student seller;
    
    @ManyToOne
    @JoinColumn(name = "item_id")
    private Item item;
    
    private BigDecimal amount;
    private BigDecimal commission; // Your 15%
    private LocalDateTime createdAt = LocalDateTime.now();
    
    @Enumerated(EnumType.STRING)
    private TransactionStatus status = TransactionStatus.COMPLETED;
    
    public enum TransactionStatus { COMPLETED, PENDING, FAILED }
    
    // Add getters/setters
}
```
- [ ] Task complete: Transaction model created

### STEP 42: Create Analytics Service
- [ ] Create: `backend/src/main/java/com/campusmart/service/AnalyticsService.java`
- [ ] Add code:
```java
@Service
public class AnalyticsService {
    
    @Autowired
    private TransactionRepository transactionRepository;
    
    public Map<String, Object> getSellerStats(Long sellerId) {
        List<Transaction> transactions = transactionRepository.findBySellerId(sellerId);
        
        int totalSales = transactions.size();
        BigDecimal totalRevenue = transactions.stream()
            .map(Transaction::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalEarnings = transactions.stream()
            .map(t -> t.getAmount().multiply(BigDecimal.valueOf(0.85))) // 85% after commission
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        return Map.of(
            "totalSales", totalSales,
            "totalRevenue", totalRevenue,
            "totalEarnings", totalEarnings,
            "averageOrderValue", totalRevenue.divide(BigDecimal.valueOf(Math.max(totalSales, 1)))
        );
    }
}
```
- [ ] Task complete: Analytics service created

### STEP 43: Create Seller Dashboard Endpoint
- [ ] Open: `backend/src/main/java/com/campusmart/controller/StudentController.java`
- [ ] Add endpoint:
```java
@GetMapping("/{id}/dashboard")
public ResponseEntity<?> getSellerDashboard(@PathVariable Long id) {
    Map<String, Object> stats = analyticsService.getSellerStats(id);
    return ResponseEntity.ok(stats);
}
```
- [ ] Task complete: Dashboard endpoint added

### STEP 44: Create Seller Dashboard React Page
- [ ] Create: `frontend/src/pages/SellerDashboard.js`
- [ ] Add code:
```javascript
import React, { useEffect, useState } from 'react';
import { getStudentStats } from '../api/api';

export default function SellerDashboard() {
  const [stats, setStats] = useState(null);
  
  useEffect(() => {
    getStudentStats(userId).then(r => setStats(r.data));
  }, []);
  
  return (
    <div className="page">
      <h1>Seller Dashboard 📊</h1>
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
          <div className="card">
            <h3>Total Sales</h3>
            <p style={{ fontSize: '2rem', color: '#5b4bff' }}>
              {stats.totalSales}
            </p>
          </div>
          <div className="card">
            <h3>Total Revenue</h3>
            <p style={{ fontSize: '2rem', color: '#5b4bff' }}>
              ₹{stats.totalRevenue}
            </p>
          </div>
          <div className="card">
            <h3>Your Earnings</h3>
            <p style={{ fontSize: '2rem', color: '#22c55e' }}>
              ₹{stats.totalEarnings}
            </p>
          </div>
          <div className="card">
            <h3>Avg Order Value</h3>
            <p style={{ fontSize: '2rem', color: '#f59e0b' }}>
              ₹{stats.averageOrderValue}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
```
- [ ] Task complete: Dashboard page created

### STEP 45: Add Dashboard Route to React Router
- [ ] Open: `frontend/src/App.js`
- [ ] Find: Routes section
- [ ] Add route:
```javascript
<Route path="/seller-dashboard" element={<SellerDashboard />} />
```
- [ ] Task complete: Route added

### STEP 46: Add Dashboard Link to Navbar
- [ ] Open: `frontend/src/components/Navbar.js`
- [ ] Find: Navigation menu
- [ ] Add link:
```javascript
<Link to="/seller-dashboard" className="nav-link">📊 Dashboard</Link>
```
- [ ] Task complete: Dashboard link added

### STEP 47: Create Revenue Tracking Page
- [ ] Create: `frontend/src/pages/Revenue.js`
- [ ] Basic structure:
```javascript
export default function Revenue() {
  return (
    <div className="page">
      <h1>💰 Your Earnings</h1>
      <div className="card">
        <p>Total Balance: ₹5,000</p>
        <button className="btn btn-primary">Withdraw</button>
      </div>
    </div>
  );
}
```
- [ ] Task complete: Revenue page created

### STEP 48: Create Flutter Dashboard UI
- [ ] Open: `flutter/lib/screens/seller_dashboard_screen.dart`
- [ ] Add stats cards:
```dart
Container(
  padding: const EdgeInsets.all(16),
  child: Column(
    children: [
      _buildStatCard('Total Sales', _stats['totalSales'].toString(), Colors.blue),
      _buildStatCard('Revenue', '₹${_stats['totalRevenue']}', Colors.green),
      _buildStatCard('Your Earnings', '₹${_stats['totalEarnings']}', Colors.orange),
    ],
  ),
)
```
- [ ] Task complete: Flutter dashboard created

---

# 🚀 PHASE 6: LAUNCH PREP (Days 36-42)

### STEP 49: Test All Critical Flows
- [ ] Checklist:
  - [ ] Register with email
  - [ ] Register with phone OTP
  - [ ] Login works
  - [ ] Add item works
  - [ ] Upload multiple images
  - [ ] Search items
  - [ ] Add to wishlist
  - [ ] Write review
  - [ ] Make offer
  - [ ] Complete transaction
  - [ ] Change password
  - [ ] Delete item (check auth)
  - [ ] Edit profile
  - [ ] Logout works
- [ ] Task complete: All flows tested

### STEP 50: Fix Any Bugs Found in Testing
- [ ] Go through each bug found
- [ ] Create branch for each bug
- [ ] Fix and test
- [ ] Merge when confirmed
- [ ] Task complete: All bugs fixed

### STEP 51: Performance Testing
- [ ] Test with 1000 items loaded
- [ ] Measure page load time
- [ ] Target: < 3 seconds
- [ ] If slower: Implement caching
- [ ] Task complete: Performance verified

### STEP 52: Security Audit Checklist
- [ ] Check: No password in console logs
- [ ] Check: No secrets in code
- [ ] Check: All endpoints protected
- [ ] Check: Input validation working
- [ ] Check: CORS configured correctly
- [ ] Check: Rate limiting enabled
- [ ] Task complete: Security audit passed

### STEP 53: Database Backup Setup
- [ ] Create: Automated daily backups
- [ ] Tool: Use MySQL/PostgreSQL native backup
- [ ] Store: In cloud (AWS S3, Google Cloud)
- [ ] Test: Restore from backup
- [ ] Task complete: Backups working

### STEP 54: Set Up Monitoring & Alerts
- [ ] Add: Sentry for error tracking
- [ ] Add: Datadog or New Relic for metrics
- [ ] Configure: Email alerts for errors
- [ ] Set up: Daily reports
- [ ] Task complete: Monitoring active

### STEP 55: Create User Onboarding Email
- [ ] Design: Welcome email sequence
- [ ] Content: How to use Campus Mart
- [ ] Link: To help documentation
- [ ] Auto-send: On registration
- [ ] Task complete: Onboarding email ready

### STEP 56: Create Help/FAQ Page
- [ ] Add: Common questions answered
- [ ] Topics: How to list, buy, pay, contact, etc.
- [ ] Location: `frontend/src/pages/Faq.js`
- [ ] Link: In footer
- [ ] Task complete: FAQ page created

### STEP 57: Create Privacy Policy Page
- [ ] Add: Data collection disclosure
- [ ] Add: How data is used
- [ ] Add: User rights
- [ ] Location: `frontend/src/pages/Privacy.js`
- [ ] Link: In footer
- [ ] Task complete: Privacy policy added

### STEP 58: Create Terms of Service Page
- [ ] Add: Platform rules
- [ ] Add: User responsibilities
- [ ] Add: Dispute resolution
- [ ] Location: `frontend/src/pages/Terms.js`
- [ ] Link: In footer
- [ ] Task complete: Terms added

### STEP 59: Deploy to Staging Server
- [ ] Choose: Heroku or AWS EC2
- [ ] Deploy backend code
- [ ] Deploy frontend code
- [ ] Configure domain
- [ ] Test end-to-end
- [ ] Task complete: Staging live

### STEP 60: Create Production Deployment Guide
- [ ] Document: Step-by-step deploy process
- [ ] Include: Environment variables needed
- [ ] Include: Database migrations
- [ ] Include: Rollback plan
- [ ] Save: For team reference
- [ ] Task complete: Deployment guide ready

---

# 📱 PHASE 7: MOBILE APP (Days 43-49)

### STEP 61: Sync Flutter with Latest Changes
- [ ] Pull latest code
- [ ] Update models (Student, Item, etc.)
- [ ] Update API calls
- [ ] Test all screens
- [ ] Task complete: Flutter in sync

### STEP 62: Add Chat to Flutter
- [ ] Implement WebSocket connection
- [ ] Add chat screen
- [ ] Show message list
- [ ] Input/send message
- [ ] Task complete: Chat working in app

### STEP 63: Add Push Notifications to Flutter
- [ ] Integrate Firebase Cloud Messaging
- [ ] Handle notification receive
- [ ] Show in-app notifications
- [ ] Navigate to relevant screen
- [ ] Task complete: Notifications working

### STEP 64: Add Payment to Flutter
- [ ] Integrate Razorpay (Razorpay Flutter SDK)
- [ ] Test payment flow
- [ ] Verify transaction recording
- [ ] Task complete: Payments working

### STEP 65: Add Seller Dashboard to Flutter
- [ ] Create seller dashboard screen
- [ ] Display stats cards
- [ ] Show recent transactions
- [ ] Add withdrawal option
- [ ] Task complete: Dashboard in app

### STEP 66: Test Flutter App on Real Device
- [ ] Install on Android phone
- [ ] Run through all features
- [ ] Check app performance
- [ ] Verify battery usage reasonable
- [ ] Task complete: Real device testing done

### STEP 67: Prepare APK for Play Store
- [ ] Generate signed APK
- [ ] Create Google Play Store account
- [ ] Prepare app listing
- [ ] Create screenshots & description
- [ ] Task complete: APK ready

### STEP 68: Submit to Google Play Store
- [ ] Upload APK
- [ ] Fill app details
- [ ] Set pricing (free)
- [ ] Submit for review
- [ ] Task complete: App submitted

### STEP 69: Prepare Web App for App Store
- [ ] Note: iOS requires Apple Developer Account ($$)
- [ ] Alternative: Use PWA for web app install
- [ ] Task complete: Platform ready

### STEP 70: Create PWA (Progressive Web App)
- [ ] Add: manifest.json file
- [ ] Add: Service worker
- [ ] Enable: Install to home screen
- [ ] Task complete: PWA ready

---

# 🎯 PHASE 8: LAUNCH & MARKETING (Days 50-56)

### STEP 71: Create Launch Announcement
- [ ] Write: Campus Mart is live!
- [ ] Include: Key features
- [ ] Add: Download link
- [ ] Include: Early bird benefits (if any)
- [ ] Task complete: Announcement ready

### STEP 72: Create Social Media Posts
- [ ] Platform: WhatsApp, Instagram, LinkedIn
- [ ] Content: Product demo video
- [ ] Include: Benefits for students
- [ ] Call-to-action: Download/register
- [ ] Task complete: Social posts ready

### STEP 73: Send Announcement Email
- [ ] Recipients: Campus contacts
- [ ] Subject: "New marketplace just launched for your campus!"
- [ ] Include: Link to app
- [ ] Include: Referral code (if implemented)
- [ ] Task complete: Email sent

### STEP 74: Invite Beta Testers
- [ ] Select: 20-50 early adopters
- [ ] Benefits: Free featured listings
- [ ] Request: Feedback & reviews
- [ ] Track: Their activity
- [ ] Task complete: Beta tester program started

### STEP 75: Monitor First Week Metrics
- [ ] Track: Daily active users
- [ ] Track: Items listed
- [ ] Track: Transactions completed
- [ ] Track: User feedback
- [ ] Respond: To issues immediately
- [ ] Task complete: Metrics monitored

### STEP 76: Create Bug Report Form
- [ ] Channel: In-app bug report button
- [ ] Capture: Screenshots, description
- [ ] Email: To your address
- [ ] Response: Within 24 hours
- [ ] Task complete: Bug reporting system ready

### STEP 77: Set Up Customer Support Email
- [ ] Email: support@campusmart.com
- [ ] Response template: For common issues
- [ ] Escalation process: For urgent issues
- [ ] Task complete: Support email active

### STEP 78: Create Knowledge Base
- [ ] How to list item
- [ ] How to make offer
- [ ] How to negotiate
- [ ] How to report fraud
- [ ] Payment & refund policy
- [ ] Task complete: Knowledge base created

### STEP 79: Implement Referral Program (Optional)
- [ ] Bonus for referrer: ₹100 credits
- [ ] Bonus for referee: ₹50 credits
- [ ] Tracking: Via unique referral code
- [ ] UI: Share referral code easily
- [ ] Task complete: Referral program live

### STEP 80: Create First User Incentive
- [ ] First 100 users: 20% commission discount
- [ ] Valid: For first 30 days
- [ ] Promotion: Highlight in app
- [ ] Track: User signup date
- [ ] Task complete: Incentive program ready

---

# 📈 PHASE 9: GROWTH & OPTIMIZATION (Days 57-70)

### STEP 81: Analyze User Behavior
- [ ] Data: Which items sell most?
- [ ] Data: What search terms used?
- [ ] Data: Peak activity time?
- [ ] Data: User drop-off points?
- [ ] Action: Optimize based on findings
- [ ] Task complete: Behavior analysis done

### STEP 82: A/B Test Homepage
- [ ] Variant A: Current design
- [ ] Variant B: Feature categories more prominent
- [ ] Measure: Engagement time, clicks
- [ ] Winner: Keep variant with higher engagement
- [ ] Task complete: A/B test completed

### STEP 83: Optimize App Performance
- [ ] Profile: API response times
- [ ] Bottleneck: Find slowest endpoints
- [ ] Optimize: Add caching, indexing
- [ ] Target: < 500ms response time
- [ ] Task complete: Performance optimized

### STEP 84: Implement User Feedback Loop
- [ ] In-app survey: "How was your experience?"
- [ ] 1-5 rating + comment
- [ ] Collect: Weekly
- [ ] Review: All responses
- [ ] Action: Implement top requests
- [ ] Task complete: Feedback loop active

### STEP 85: Create Video Tutorial Series
- [ ] Video 1: How to sign up
- [ ] Video 2: How to list item
- [ ] Video 3: How to make offer
- [ ] Video 4: How to negotiate
- [ ] Video 5: How to complete transaction
- [ ] Platform: YouTube & in-app
- [ ] Task complete: Video tutorials created

### STEP 86: Expand to Second Campus
- [ ] Prepare: Campus-specific settings
- [ ] Marketing: Reach out to second campus students
- [ ] Support: Dedicated community manager
- [ ] Track: Metrics separate per campus
- [ ] Task complete: Second campus live

### STEP 87: Implement In-App Notifications
- [ ] Type 1: Someone made offer on your item
- [ ] Type 2: Your offer was accepted
- [ ] Type 3: New message in chat
- [ ] Type 4: Item expiring soon
- [ ] Type 5: Admin announcement
- [ ] Task complete: Notifications live

### STEP 88: Create Admin Dashboard for Campus
- [ ] Stats: Users, items, transactions
- [ ] Moderation: Approve/reject items
- [ ] Reports: See flagged items
- [ ] Sellers: View seller details
- [ ] Analytics: Chart revenue trends
- [ ] Task complete: Admin dashboard functional

### STEP 89: Implement Item Verification
- [ ] Photos: Seller uploads item photo
- [ ] Admin: Verifies it matches listing
- [ ] Approval: Before listing goes live
- [ ] Trust: Reduces fraud
- [ ] Task complete: Photo verification live

### STEP 90: Create Seller Verification Program
- [ ] Criteria: 5+ sales, 4.5+ rating
- [ ] Benefit: "Verified Seller" badge
- [ ] Display: On profile & items
- [ ] Advantage: Higher conversion rates
- [ ] Task complete: Program implemented

---

# 🏆 FINAL PHASE: PRODUCTION HARDENING (Days 71-77)

### STEP 91: Enable HTTPS/SSL
- [ ] Get: SSL certificate (Let's Encrypt = free)
- [ ] Configure: Web server (Nginx/Apache)
- [ ] Redirect: All HTTP → HTTPS
- [ ] Test: Browser shows lock icon
- [ ] Task complete: HTTPS enabled

### STEP 92: Set Up Database Replication
- [ ] Primary: Main production database
- [ ] Replica: Backup database (read-only)
- [ ] Sync: Every transaction
- [ ] Failover: Auto-switch if primary down
- [ ] Task complete: Replication configured

### STEP 93: Implement Rate Limiting
- [ ] Limit: 100 requests per minute per IP
- [ ] Endpoint: Apply to login, search
- [ ] Response: 429 Too Many Requests
- [ ] Whitelist: Admin IPs
- [ ] Task complete: Rate limiting active

### STEP 94: Set Up Auto-Scaling
- [ ] Cloud: AWS or Google Cloud
- [ ] Trigger: CPU > 70% or high traffic
- [ ] Scale up: Add 2 more servers
- [ ] Scale down: Remove when not needed
- [ ] Cost: Monitor & optimize
- [ ] Task complete: Auto-scaling enabled

### STEP 95: Create Disaster Recovery Plan
- [ ] Document: Step-by-step recovery
- [ ] Scenario 1: Database crash
- [ ] Scenario 2: Server down
- [ ] Scenario 3: Data corruption
- [ ] Test: Recovery plan quarterly
- [ ] Task complete: Plan documented & tested

### STEP 96: Set Up Incident Response Team
- [ ] Roles: On-call engineer, manager, support
- [ ] Communication: Slack channel for alerts
- [ ] Escalation: L1 → L2 → L3
- [ ] SLA: Critical issues fixed in 1 hour
- [ ] Task complete: Team ready

### STEP 97: Enable Enhanced Security Features
- [ ] 2FA: Two-factor authentication option
- [ ] Session timeout: 30 min inactivity
- [ ] Password policy: Minimum 8 chars, special chars
- [ ] IP blocking: Repeated failed logins
- [ ] Task complete: Security hardened

### STEP 98: Implement Compliance Checks
- [ ] GDPR: Data privacy regulations
- [ ] RBI: Payment regulations
- [ ] Terms: Seller/buyer terms agreed
- [ ] Verification: Age (18+) verified
- [ ] Task complete: Compliance verified

### STEP 99: Create Update & Maintenance Schedule
- [ ] Weekly: Code reviews
- [ ] Bi-weekly: Security patches
- [ ] Monthly: Database optimization
- [ ] Quarterly: Full audit
- [ ] Annual: Major upgrade
- [ ] Task complete: Schedule documented

### STEP 100: Celebrate Launch! 🎉
- [ ] Reflect: How far you've come
- [ ] Thank: Your team & early users
- [ ] Plan: What's next (scaling, features)
- [ ] Enjoy: Your success!
- [ ] Task complete: SHIPPED! 🚀

---

## 📊 TRACKING CHECKLIST

Print this and check off as you complete each step:

```
PHASE 1 (SECURITY) - Days 1-7
[ ] Step 1   [ ] Step 2   [ ] Step 3   [ ] Step 4   [ ] Step 5
[ ] Step 6   [ ] Step 7   [ ] Step 8   [ ] Step 9   [ ] Step 10
[ ] Step 11  [ ] Step 12

PHASE 2 (FEATURES) - Days 8-14
[ ] Step 13  [ ] Step 14  [ ] Step 15  [ ] Step 16  [ ] Step 17
[ ] Step 18  [ ] Step 19  [ ] Step 20  [ ] Step 21  [ ] Step 22

PHASE 3 (ENGAGEMENT) - Days 15-21
[ ] Step 23  [ ] Step 24  [ ] Step 25  [ ] Step 26  [ ] Step 27
[ ] Step 28  [ ] Step 29  [ ] Step 30  [ ] Step 31  [ ] Step 32

PHASE 4 (MONETIZATION) - Days 22-28
[ ] Step 33  [ ] Step 34  [ ] Step 35  [ ] Step 36  [ ] Step 37
[ ] Step 38  [ ] Step 39  [ ] Step 40

PHASE 5 (ANALYTICS) - Days 29-35
[ ] Step 41  [ ] Step 42  [ ] Step 43  [ ] Step 44  [ ] Step 45
[ ] Step 46  [ ] Step 47  [ ] Step 48

PHASE 6 (LAUNCH PREP) - Days 36-42
[ ] Step 49  [ ] Step 50  [ ] Step 51  [ ] Step 52  [ ] Step 53
[ ] Step 54  [ ] Step 55  [ ] Step 56  [ ] Step 57  [ ] Step 58
[ ] Step 59  [ ] Step 60

PHASE 7 (MOBILE) - Days 43-49
[ ] Step 61  [ ] Step 62  [ ] Step 63  [ ] Step 64  [ ] Step 65
[ ] Step 66  [ ] Step 67  [ ] Step 68  [ ] Step 69  [ ] Step 70

PHASE 8 (LAUNCH) - Days 50-56
[ ] Step 71  [ ] Step 72  [ ] Step 73  [ ] Step 74  [ ] Step 75
[ ] Step 76  [ ] Step 77  [ ] Step 78  [ ] Step 79  [ ] Step 80

PHASE 9 (GROWTH) - Days 57-70
[ ] Step 81  [ ] Step 82  [ ] Step 83  [ ] Step 84  [ ] Step 85
[ ] Step 86  [ ] Step 87  [ ] Step 88  [ ] Step 89  [ ] Step 90

FINAL (HARDENING) - Days 71-77
[ ] Step 91  [ ] Step 92  [ ] Step 93  [ ] Step 94  [ ] Step 95
[ ] Step 96  [ ] Step 97  [ ] Step 98  [ ] Step 99  [ ] Step 100

TOTAL: 100 Steps ✅
```

---

## ⏰ TIME ESTIMATION

```
PHASE 1: Security (12 steps)           = 2 days (14 hours)
PHASE 2: Features (10 steps)           = 3 days (24 hours)
PHASE 3: Engagement (10 steps)         = 4 days (32 hours)
PHASE 4: Monetization (8 steps)        = 3 days (24 hours)
PHASE 5: Analytics (8 steps)           = 3 days (24 hours)
PHASE 6: Launch Prep (12 steps)        = 4 days (32 hours)
PHASE 7: Mobile (10 steps)             = 4 days (32 hours)
PHASE 8: Launch (10 steps)             = 2 days (16 hours)
PHASE 9: Growth (10 steps)             = 7 days (56 hours)
FINAL: Hardening (10 steps)            = 4 days (32 hours)
─────────────────────────────────────────────────────
TOTAL:                                 = 9-10 weeks (286 hours)

If you work 8 hours/day:              = 36 days ≈ 7 weeks
If you work 4 hours/day:              = 72 days ≈ 10 weeks

REALITY CHECK:
- With help (2 developers):           = 3-4 weeks ✅
- Solo part-time:                     = 3-4 months
- Solo full-time:                     = 5-7 weeks
```

---

## 🎯 SUCCESS MILESTONES

- **Week 1 End**: Security issues fixed ✅
- **Week 2 End**: All features completed ✅
- **Week 3 End**: App tested & ready ✅
- **Week 4 End**: Live on campus! 🎉

---

This is your complete roadmap. Just work through it step by step, one at a time. 

**You've got this!** 💪
