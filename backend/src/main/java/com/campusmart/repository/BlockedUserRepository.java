package com.campusmart.repository;

import com.campusmart.model.BlockedUser;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BlockedUserRepository extends JpaRepository<BlockedUser, Long> {

    boolean existsByBlockerIdAndBlockedId(Long blockerId, Long blockedId);

    boolean existsByBlockerIdAndBlockedIdOrBlockerIdAndBlockedId(
        Long blockerId,
        Long blockedId,
        Long reverseBlockerId,
        Long reverseBlockedId
    );

    Optional<BlockedUser> findByBlockerIdAndBlockedId(Long blockerId, Long blockedId);

    List<BlockedUser> findByBlockerIdOrderByCreatedAtDesc(Long blockerId);
}
