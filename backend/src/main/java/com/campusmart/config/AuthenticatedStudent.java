package com.campusmart.config;

import com.campusmart.model.Student;
import com.campusmart.model.Student.StudentRole;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.Collection;
import java.util.List;

public class AuthenticatedStudent {

    private final Long id;
    private final String email;
    private final StudentRole role;

    public AuthenticatedStudent(Long id, String email, StudentRole role) {
        this.id = id;
        this.email = email;
        this.role = role == null ? StudentRole.STUDENT : role;
    }

    public static AuthenticatedStudent from(Student student) {
        return new AuthenticatedStudent(student.getId(), student.getEmail(), student.getRole());
    }

    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public StudentRole getRole() {
        return role;
    }

    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }
}
