package com.campusmart.repository;

import com.campusmart.model.RegistrationSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import jakarta.transaction.Transactional;
import java.util.Optional;

@Repository
public interface RegistrationSessionRepository extends JpaRepository<RegistrationSession, Long> {
    Optional<RegistrationSession> findByEmail(String email);
    Optional<RegistrationSession> findByPhone(String phone);
}
