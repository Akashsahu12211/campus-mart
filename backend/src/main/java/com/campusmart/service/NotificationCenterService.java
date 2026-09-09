package com.campusmart.service;

import com.campusmart.model.NotificationEntry;
import com.campusmart.model.Student;
import com.campusmart.repository.NotificationEntryRepository;
import com.campusmart.repository.StudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NotificationCenterService {

    @Autowired private NotificationEntryRepository notificationEntryRepository;
    @Autowired private StudentRepository studentRepository;

    public NotificationEntry createNotification(Long studentId, String title, String body, String type, String clickAction) {
        Student student = studentRepository.findById(studentId)
            .orElseThrow(() -> new RuntimeException("Student not found"));

        NotificationEntry entry = new NotificationEntry();
        entry.setStudent(student);
        entry.setTitle(title);
        entry.setBody(body);
        entry.setType(type);
        entry.setClickAction(clickAction);
        return notificationEntryRepository.save(entry);
    }

    public List<NotificationEntry> getNotifications(Long studentId) {
        return notificationEntryRepository.findTop50ByStudentIdOrderByCreatedAtDesc(studentId);
    }

    public NotificationEntry markRead(Long studentId, Long notificationId) {
        NotificationEntry entry = notificationEntryRepository.findById(notificationId)
            .orElseThrow(() -> new RuntimeException("Notification not found"));
        if (!entry.getStudent().getId().equals(studentId)) {
            throw new RuntimeException("Cannot update another user's notification");
        }
        entry.setRead(true);
        return notificationEntryRepository.save(entry);
    }

    public long markAllRead(Long studentId) {
        List<NotificationEntry> notifications = notificationEntryRepository.findTop50ByStudentIdOrderByCreatedAtDesc(studentId);
        notifications.forEach(notification -> notification.setRead(true));
        notificationEntryRepository.saveAll(notifications);
        return notifications.size();
    }

    public long getUnreadCount(Long studentId) {
        return notificationEntryRepository.countByStudentIdAndIsReadFalse(studentId);
    }
}
