package com.campusmart.repository;

import com.campusmart.model.Student;
import com.campusmart.model.Student.StudentRole;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface StudentRepository extends JpaRepository<Student, Long> {

    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);
    boolean existsByPhoneAndIdNot(String phone, Long id);
    Optional<Student> findByEmail(String email);
    Optional<Student> findByGoogleId(String googleId);
    Optional<Student> findByFacebookId(String facebookId);

    // ── Admin Panel Methods ────────────────────────────────
    long countByIsBanned(boolean isBanned);
    long countByRole(StudentRole role);
    long countByAuthProvider(Student.AuthProvider authProvider);
    long countByContactAccessTier(Student.ContactAccessTier contactAccessTier);
    long countByActiveSubscriptionCode(String activeSubscriptionCode);
    long countByCreatedAtAfter(LocalDateTime date);
    long countByCreatedAtBetween(LocalDateTime from, LocalDateTime to);
    List<Student> findAllByOrderByCreatedAtDesc();
    List<Student> findByIdNotAndIsActiveTrueAndIsBannedFalse(Long id);
    Page<Student> findByIdNotAndIsActiveTrueAndIsBannedFalse(Long id, Pageable pageable);
    List<Student> findByNameContainingIgnoreCaseOrEmailContainingIgnoreCase(
        String name, String email);

}
