package com.campusmart.service;

import com.campusmart.model.Student;
import com.campusmart.model.Student.ContactAccessTier;
import com.campusmart.repository.StudentRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

@Service
public class StudentService {

    @Autowired
    private StudentRepository studentRepository;

    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$"
    );

    @Value("${app.enforce-contact-access-gating:false}")
    private boolean enforceContactAccessGating;

    public Student register(Student student) {
        if (student.getName() == null || student.getName().trim().length() < 2) {
            throw new RuntimeException("Name must be at least 2 characters.");
        }

        if (student.getEmail() == null || !EMAIL_PATTERN.matcher(student.getEmail().trim()).matches()) {
            throw new RuntimeException("Please enter a valid email address.");
        }

        if (studentRepository.existsByEmail(student.getEmail().trim().toLowerCase())) {
            throw new RuntimeException("This email is already registered. Please login.");
        }

        if (student.getPassword() == null || student.getPassword().length() < 6) {
            throw new RuntimeException("Password must be at least 6 characters.");
        }

        student.setEmail(student.getEmail().trim().toLowerCase());
        student.setName(student.getName().trim());
        student.setPassword(passwordEncoder.encode(student.getPassword()));

        return studentRepository.save(student);
    }

    public Student login(String email, String password) {
        if (email == null || !EMAIL_PATTERN.matcher(email.trim()).matches()) {
            throw new RuntimeException("Please enter a valid email address.");
        }

        if (password == null || password.isEmpty()) {
            throw new RuntimeException("Password cannot be empty.");
        }

        Student student = studentRepository.findByEmail(email.trim().toLowerCase())
                .orElseThrow(() -> new RuntimeException("No account found with this email. Please register first."));

        if (!passwordEncoder.matches(password, student.getPassword())) {
            throw new RuntimeException("Incorrect password. Please try again.");
        }

        return student;
    }

    public List<Student> getAllStudents() {
        return studentRepository.findAll();
    }

    public Optional<Student> getStudentById(Long id) {
        return studentRepository.findById(id);
    }

    public Student updateStudent(Long id, Student updatedStudent) {
        Student existing = studentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Student not found!"));

        if (updatedStudent.getName() != null && !updatedStudent.getName().trim().isEmpty()) {
            existing.setName(updatedStudent.getName().trim());
        }
        if (updatedStudent.getPhone() != null) {
            String nextPhone = updatedStudent.getPhone().trim();
            if (!nextPhone.equals(existing.getPhone())) {
                if (!nextPhone.isEmpty() && studentRepository.existsByPhoneAndIdNot(nextPhone, existing.getId())) {
                    throw new RuntimeException("This phone number is already registered");
                }
                existing.setPhone(nextPhone.isEmpty() ? null : nextPhone);
                existing.setPhoneVerified(false);
            }
        }
        if (updatedStudent.getBranch() != null) {
            existing.setBranch(updatedStudent.getBranch());
        }
        if (updatedStudent.getHostel() != null) {
            existing.setHostel(updatedStudent.getHostel());
        }
        if (updatedStudent.getCollegeId() != null) {
            existing.setCollegeId(updatedStudent.getCollegeId());
        }
        if (updatedStudent.getInstitution() != null) {
            existing.setInstitution(updatedStudent.getInstitution());
        }
        if (updatedStudent.getInstitutionType() != null) {
            existing.setInstitutionType(updatedStudent.getInstitutionType());
        }
        if (updatedStudent.getInstitutionName() != null) {
            existing.setInstitutionName(updatedStudent.getInstitutionName());
        }
        if (updatedStudent.getCampusName() != null) {
            existing.setCampusName(updatedStudent.getCampusName());
        }
        if (updatedStudent.getCourseName() != null) {
            existing.setCourseName(updatedStudent.getCourseName());
        }
        if (updatedStudent.getClassLevel() != null) {
            existing.setClassLevel(updatedStudent.getClassLevel());
        }
        if (updatedStudent.getCity() != null) {
            existing.setCity(updatedStudent.getCity());
        }
        if (updatedStudent.getStateName() != null) {
            existing.setStateName(updatedStudent.getStateName());
        }
        if (updatedStudent.getCountryName() != null) {
            existing.setCountryName(updatedStudent.getCountryName());
        }
        if (updatedStudent.getProfilePic() != null) {
            existing.setProfilePic(updatedStudent.getProfilePic());
        }
        if (updatedStudent.getBio() != null) {
            existing.setBio(updatedStudent.getBio());
        }
        if (updatedStudent.getPushNotificationsEnabled() != null) {
            existing.setPushNotificationsEnabled(updatedStudent.getPushNotificationsEnabled());
        }
        if (updatedStudent.getEmailNotificationsEnabled() != null) {
            existing.setEmailNotificationsEnabled(updatedStudent.getEmailNotificationsEnabled());
        }
        if (updatedStudent.getShowPhoneOnListings() != null) {
            existing.setShowPhoneOnListings(updatedStudent.getShowPhoneOnListings());
        }
        if (updatedStudent.getAllowDirectChat() != null) {
            existing.setAllowDirectChat(updatedStudent.getAllowDirectChat());
        }
        if (updatedStudent.getPrivacyMode() != null && !updatedStudent.getPrivacyMode().isBlank()) {
            existing.setPrivacyMode(updatedStudent.getPrivacyMode());
        }
        if (updatedStudent.getPreferredLanguage() != null && !updatedStudent.getPreferredLanguage().isBlank()) {
            existing.setPreferredLanguage(updatedStudent.getPreferredLanguage());
        }
        if (updatedStudent.getLocationLabel() != null) {
            existing.setLocationLabel(updatedStudent.getLocationLabel());
        }
        if (updatedStudent.getLatitude() != null) {
            existing.setLatitude(updatedStudent.getLatitude());
        }
        if (updatedStudent.getLongitude() != null) {
            existing.setLongitude(updatedStudent.getLongitude());
        }

        if (updatedStudent.getPassword() != null && !updatedStudent.getPassword().isEmpty()) {
            if (updatedStudent.getPassword().length() < 6) {
                throw new RuntimeException("New password must be at least 6 characters.");
            }
            existing.setPassword(passwordEncoder.encode(updatedStudent.getPassword()));
        }

        return studentRepository.save(existing);
    }

    public void deleteStudent(Long id) {
        studentRepository.deleteById(id);
    }

    public void prepareStudentForViewer(Student target, Student viewer) {
        if (target == null) {
            return;
        }

        String originalPhone = target.getPhone();
        boolean hasPhone = originalPhone != null && !originalPhone.isBlank();
        boolean identityVerified = Boolean.TRUE.equals(target.getEmailVerified())
            && Boolean.TRUE.equals(target.getPhoneVerified())
            && Boolean.TRUE.equals(target.getIsActive())
            && !Boolean.TRUE.equals(target.getIsBanned());

        boolean isOwner = viewer != null
            && viewer.getId() != null
            && viewer.getId().equals(target.getId());
        boolean viewerPrivileged = viewer != null
            && viewer.getRole() != null
            && (viewer.getRole() == Student.StudentRole.ADMIN
                || viewer.getRole() == Student.StudentRole.MODERATOR);
        boolean sellerAllowsPhone = !Boolean.FALSE.equals(target.getShowPhoneOnListings());
        boolean viewerHasContactAccess = hasActiveContactAccess(viewer);
        boolean phoneVisible = false;
        String revealReason;

        if (!hasPhone) {
            revealReason = "UNAVAILABLE";
        } else if (isOwner || viewerPrivileged) {
            phoneVisible = true;
            revealReason = "OWNER";
        } else if (!sellerAllowsPhone) {
            revealReason = "SELLER_HIDDEN";
        } else if (!enforceContactAccessGating) {
            phoneVisible = viewer != null;
            revealReason = viewer != null ? "VISIBLE" : "LOGIN_REQUIRED";
        } else if (viewer == null) {
            revealReason = "LOGIN_REQUIRED";
        } else if (viewerHasContactAccess) {
            phoneVisible = true;
            revealReason = "VISIBLE";
        } else {
            revealReason = "SUBSCRIPTION_REQUIRED";
        }

        target.setIdentityVerified(identityVerified);
        target.setPhoneVisibleToViewer(phoneVisible);
        target.setContactRevealReason(revealReason);
        target.setMaskedPhone(
            hasPhone && (sellerAllowsPhone || isOwner || viewerPrivileged)
                ? maskPhone(originalPhone)
                : null
        );
        target.setPhone(phoneVisible ? originalPhone : null);
    }

    public boolean hasActiveContactAccess(Student student) {
        if (student == null || student.getContactAccessTier() == null) {
            return false;
        }

        if (student.getContactAccessTier() == ContactAccessTier.FREE) {
            return false;
        }

        return student.getContactAccessExpiresAt() == null
            || student.getContactAccessExpiresAt().isAfter(LocalDateTime.now());
    }

    public java.util.Map<String, Object> getStudentStats(Long id) {
        Student student = studentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Student not found!"));
        java.util.Map<String, Object> stats = new java.util.HashMap<>();
        stats.put("totalListings", student.getListedItems() != null ? student.getListedItems().size() : 0);
        stats.put("memberSince", student.getCreatedAt());
        return stats;
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 4) {
            return phone;
        }
        return "XXXXXX" + phone.substring(phone.length() - 4);
    }
}
