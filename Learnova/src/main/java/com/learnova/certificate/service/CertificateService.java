package com.learnova.certificate.service;

import com.learnova.certificate.dto.CertificateResponse;
import com.learnova.certificate.dto.CertificateVerificationResponse;
import com.learnova.certificate.repository.CertificateRepository;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CertificateService {

    private final CertificateRepository certificateRepository;
    private final CurrentUserResolver currentUserResolver;

    public CertificateService(
            CertificateRepository certificateRepository,
            CurrentUserResolver currentUserResolver
    ) {
        this.certificateRepository = certificateRepository;
        this.currentUserResolver = currentUserResolver;
    }

    public List<CertificateResponse> listMine() {
        return certificateRepository.findByUser(currentUserResolver.getCurrentUserId());
    }

    public CertificateResponse issueCourse(Long courseId) {
        validateId(courseId, "courseId");
        return certificateRepository.issue(
                currentUserResolver.getCurrentUserId(),
                "course",
                courseId
        );
    }

    public CertificateResponse issueTrack(Long trackId) {
        validateId(trackId, "trackId");
        return certificateRepository.issue(
                currentUserResolver.getCurrentUserId(),
                "track",
                trackId
        );
    }

    public CertificateVerificationResponse verify(String code) {
        if (code == null || code.isBlank()) {
            throw new IllegalArgumentException("Certificate code is required.");
        }
        CertificateVerificationResponse result =
                certificateRepository.verify(code.strip());
        if (result == null) {
            throw new ResourceNotFoundException("Certificate was not found.");
        }
        return result;
    }

    private void validateId(Long id, String name) {
        if (id == null || id < 1) {
            throw new IllegalArgumentException(name + " must be greater than zero.");
        }
    }
}