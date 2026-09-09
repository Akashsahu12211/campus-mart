package com.campusmart.service;

import com.campusmart.model.BlockedUser;
import com.campusmart.model.Student;
import com.campusmart.repository.BlockedUserRepository;
import com.campusmart.repository.StudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class BlockService {

    @Autowired private BlockedUserRepository blockedUserRepository;
    @Autowired private StudentRepository studentRepository;

    public BlockedUser blockUser(Long blockerId, Long blockedId) {
        if (blockerId.equals(blockedId)) {
            throw new RuntimeException("You cannot block yourself");
        }

        if (blockedUserRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)) {
            throw new RuntimeException("User already blocked");
        }

        Student blocker = studentRepository.findById(blockerId)
            .orElseThrow(() -> new RuntimeException("Blocker not found"));
        Student blocked = studentRepository.findById(blockedId)
            .orElseThrow(() -> new RuntimeException("Blocked user not found"));

        BlockedUser blockedUser = new BlockedUser();
        blockedUser.setBlocker(blocker);
        blockedUser.setBlocked(blocked);
        return blockedUserRepository.save(blockedUser);
    }

    public void unblockUser(Long blockerId, Long blockedId) {
        BlockedUser blockedUser = blockedUserRepository.findByBlockerIdAndBlockedId(blockerId, blockedId)
            .orElseThrow(() -> new RuntimeException("Blocked user not found"));
        blockedUserRepository.delete(blockedUser);
    }

    public boolean isBlockedEitherWay(Long firstUserId, Long secondUserId) {
        return blockedUserRepository.existsByBlockerIdAndBlockedIdOrBlockerIdAndBlockedId(
            firstUserId, secondUserId, secondUserId, firstUserId
        );
    }

    public boolean isBlockedByViewer(Long viewerId, Long targetUserId) {
        return blockedUserRepository.existsByBlockerIdAndBlockedId(viewerId, targetUserId);
    }

    public List<BlockedUser> getBlockedUsers(Long blockerId) {
        return blockedUserRepository.findByBlockerIdOrderByCreatedAtDesc(blockerId);
    }
}
