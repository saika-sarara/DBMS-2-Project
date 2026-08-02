package com.learnova.instructor.repository;

import com.learnova.instructor.model.InstructorRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface InstructorRequestRepository extends JpaRepository<InstructorRequest, Long> {

    List<InstructorRequest> findAllByOrderByCreatedAtDesc();

    List<InstructorRequest> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<InstructorRequest> findFirstByUserIdOrderByCreatedAtDesc(Long userId);

    boolean existsByUserIdAndStatus(Long userId, String status);
}
