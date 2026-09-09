package com.campusmart.repository;

import com.campusmart.model.Institution;
import com.campusmart.model.Student;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface InstitutionRepository extends JpaRepository<Institution, Long> {

    List<Institution> findTop50ByIsActiveTrueOrderByVerifiedDescNameAsc();

    @Query("""
        select i from Institution i
        where i.isActive = true
          and (:query is null or lower(i.name) like lower(concat('%', :query, '%')))
          and (:institutionType is null or i.institutionType = :institutionType)
          and (:city is null or lower(i.city) = lower(:city))
          and (:stateName is null or lower(i.stateName) = lower(:stateName))
        order by i.verified desc, i.name asc
        """)
    List<Institution> searchActiveInstitutions(
        @Param("query") String query,
        @Param("institutionType") Student.InstitutionType institutionType,
        @Param("city") String city,
        @Param("stateName") String stateName
    );
}
