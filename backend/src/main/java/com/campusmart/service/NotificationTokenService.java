package com.campusmart.service;

import com.campusmart.dto.NotificationTokenRequest;
import com.campusmart.model.Student;
import com.campusmart.model.StudentFcmToken;
import com.campusmart.repository.StudentFcmTokenRepository;
import com.campusmart.repository.StudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class NotificationTokenService {

    @Autowired
    private StudentRepository studentRepository;

    @Autowired
    private StudentFcmTokenRepository studentFcmTokenRepository;

    public Student saveToken(NotificationTokenRequest request) {
        if (request == null || request.getUserId() == null) {
            throw new RuntimeException("User ID is required");
        }
        if (request.getFcmToken() == null || request.getFcmToken().isBlank()) {
            throw new RuntimeException("FCM token is required");
        }

        Student student = studentRepository.findById(request.getUserId())
                .orElseThrow(() -> new RuntimeException("Student not found"));

        student.setDeviceToken(request.getFcmToken().trim());
        student.setDevicePlatform(
                request.getPlatform() != null && !request.getPlatform().isBlank()
                        ? request.getPlatform().trim().toUpperCase()
                        : "UNKNOWN"
        );
        Student savedStudent = studentRepository.save(student);

        StudentFcmToken tokenRecord = studentFcmTokenRepository.findByFcmToken(request.getFcmToken().trim())
                .orElseGet(StudentFcmToken::new);
        tokenRecord.setStudent(savedStudent);
        tokenRecord.setFcmToken(request.getFcmToken().trim());
        tokenRecord.setPlatform(savedStudent.getDevicePlatform());
        studentFcmTokenRepository.save(tokenRecord);

        return savedStudent;
    }

    public Student clearToken(NotificationTokenRequest request) {
        if (request == null || request.getUserId() == null) {
            throw new RuntimeException("User ID is required");
        }

        Student student = studentRepository.findById(request.getUserId())
                .orElseThrow(() -> new RuntimeException("Student not found"));

        String existingToken = student.getDeviceToken();
        String incomingToken = request.getFcmToken() != null ? request.getFcmToken().trim() : null;

        if (existingToken != null && incomingToken != null && !incomingToken.isBlank() && !existingToken.equals(incomingToken)) {
            studentFcmTokenRepository.deleteByStudentIdAndFcmToken(student.getId(), incomingToken);
            return student;
        }

        student.setDeviceToken(null);
        student.setDevicePlatform(null);
        Student savedStudent = studentRepository.save(student);

        if (incomingToken != null && !incomingToken.isBlank()) {
            studentFcmTokenRepository.deleteByStudentIdAndFcmToken(student.getId(), incomingToken);
        } else {
            List<StudentFcmToken> tokens = studentFcmTokenRepository.findByStudentId(student.getId());
            studentFcmTokenRepository.deleteAll(tokens);
        }

        return savedStudent;
    }

    public Set<String> getTokensForStudent(Long studentId, String fallbackToken) {
        Set<String> tokens = studentFcmTokenRepository.findByStudentId(studentId).stream()
                .map(StudentFcmToken::getFcmToken)
                .filter(token -> token != null && !token.isBlank())
                .collect(Collectors.toSet());

        if (fallbackToken != null && !fallbackToken.isBlank()) {
            tokens.add(fallbackToken.trim());
        }

        return tokens;
    }
}
