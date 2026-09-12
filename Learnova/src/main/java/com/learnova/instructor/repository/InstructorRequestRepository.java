package com.learnova.instructor.repository;

import com.learnova.instructor.dto.InstructorRequestView;
import com.learnova.instructor.model.InstructorRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface InstructorRequestRepository extends JpaRepository<InstructorRequest, Long> {

    @Query("""
            SELECT
                r.id AS id,
                r.userId AS userId,
                r.requestMessage AS note,
                r.status AS status,
                r.createdAt AS requestedAt,
                u.firstName AS firstName,
                u.lastName AS lastName,
                u.email AS email
            FROM InstructorRequest r
            LEFT JOIN User u ON u.id = r.userId
            ORDER BY r.createdAt DESC
            """)
    List<InstructorRequestView> findAllWithUserOrderByCreatedAtDesc();

    List<InstructorRequest> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<InstructorRequest> findFirstByUserIdOrderByCreatedAtDesc(Long userId);

    boolean existsByUserIdAndStatus(Long userId, String status);
}
