package com.learnova.enrollment.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.enrollment.dto.DatabaseAccessResult;
import com.learnova.enrollment.dto.DatabaseEnrollmentResult;
import com.learnova.enrollment.dto.EnrollmentAccessResponse;
import com.learnova.enrollment.dto.EnrollmentRequest;
import com.learnova.enrollment.dto.EnrollmentResponse;
import com.learnova.enrollment.dto.EnrollmentStatsResponse;
import com.learnova.enrollment.repository.EnrollmentCommandRepository;
import com.learnova.enrollment.repository.EnrollmentRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

import java.sql.SQLException;
import java.util.List;

@Service
public class EnrollmentService {

    private final CurrentUserResolver currentUserResolver;
    private final EnrollmentCommandRepository commandRepository;
    private final EnrollmentRepository enrollmentRepository;

    public EnrollmentService(CurrentUserResolver currentUserResolver,
                             EnrollmentCommandRepository commandRepository,
                             EnrollmentRepository enrollmentRepository) {
        this.currentUserResolver = currentUserResolver;
        this.commandRepository = commandRepository;
        this.enrollmentRepository = enrollmentRepository;
    }

    public EnrollmentResponse enrollInCourse(EnrollmentRequest request) {
        Long studentId = currentUserResolver.getCurrentUserId();
        try {
            DatabaseEnrollmentResult result = commandRepository.enrollInCourse(studentId, request.getCourseId());
            return EnrollmentResponse.from(result, "COURSE");
        } catch (DataAccessException ex) {
            throw translateDataAccess(ex);
        }
    }

    public EnrollmentResponse enrollInTrack(EnrollmentRequest request) {
        Long studentId = currentUserResolver.getCurrentUserId();
        try {
            DatabaseEnrollmentResult result = commandRepository.enrollInTrack(studentId, request.getTrackId());
            return EnrollmentResponse.from(result, "TRACK");
        } catch (DataAccessException ex) {
            throw translateDataAccess(ex);
        }
    }

    public List<EnrollmentResponse> getMyCourses() {
        Long studentId = currentUserResolver.getCurrentUserId();
        return enrollmentRepository.findMyCourses(studentId);
    }

    public List<EnrollmentResponse> getMyTracks() {
        Long studentId = currentUserResolver.getCurrentUserId();
        return enrollmentRepository.findMyTracks(studentId);
    }

    public EnrollmentAccessResponse getCourseAccess(Long courseId) {
        Long studentId = currentUserResolver.getCurrentUserId();
        DatabaseAccessResult result = enrollmentRepository.findCourseAccess(studentId, courseId);
        return EnrollmentAccessResponse.from(result, courseId);
    }

    public EnrollmentStatsResponse getAdminStats() {
        return enrollmentRepository.getStats();
    }

    private RuntimeException translateDataAccess(DataAccessException ex) {
        Throwable cause = ex.getMostSpecificCause();
        if (cause instanceof SQLException sqlEx) {
            return new DatabaseException(sqlEx.getSQLState(), sqlEx.getMessage());
        }
        return new DatabaseException(null, "Database error: " + ex.getMessage());
    }
}
