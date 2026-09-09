package com.campusmart.controller;

import com.campusmart.model.Institution;
import com.campusmart.model.Student;
import com.campusmart.repository.InstitutionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/institutions")
public class InstitutionController {

    @Autowired
    private InstitutionRepository institutionRepository;

    @GetMapping
    public ResponseEntity<List<Institution>> getInstitutions() {
        return ResponseEntity.ok(institutionRepository.findTop50ByIsActiveTrueOrderByVerifiedDescNameAsc());
    }

    @GetMapping("/search")
    public ResponseEntity<List<Institution>> searchInstitutions(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Student.InstitutionType type,
            @RequestParam(required = false) String city,
            @RequestParam(required = false) String state) {
        return ResponseEntity.ok(
            institutionRepository.searchActiveInstitutions(
                normalize(q),
                type,
                normalize(city),
                normalize(state)
            )
        );
    }

    private String normalize(String value) {
        return value != null && !value.isBlank() ? value.trim() : null;
    }
}
