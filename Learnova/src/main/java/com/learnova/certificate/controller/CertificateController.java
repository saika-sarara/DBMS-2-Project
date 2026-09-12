package com.learnova.certificate.controller;

import com.learnova.certificate.dto.CertificateResponse;
import com.learnova.certificate.dto.CertificateVerificationResponse;
import com.learnova.certificate.service.CertificateService;
import com.learnova.common.response.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/certificates")
public class CertificateController {

    private final CertificateService certificateService;

    public CertificateController(CertificateService certificateService) {
        this.certificateService = certificateService;
    }

    @GetMapping("/mine")
    public ResponseEntity<ApiResponse<List<CertificateResponse>>> listMine() {
        return ResponseEntity.ok(ApiResponse.ok(certificateService.listMine()));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CertificateResponse>> issue(
            @Valid @RequestBody CertificateIssueRequest request
    ) {
        String type = request.type() == null || request.type().isBlank()
                ? "course"
                : request.type();
        if (!type.equalsIgnoreCase("course") && !type.equalsIgnoreCase("track")) {
            throw new IllegalArgumentException("type must be course or track.");
        }
        CertificateResponse response = "track".equalsIgnoreCase(type)
                ? certificateService.issueTrack(request.entityId())
                : certificateService.issueCourse(request.entityId());
        return ResponseEntity.ok(ApiResponse.ok("Certificate issued.", response));
    }

    @GetMapping("/verify/{code}")
    public ResponseEntity<ApiResponse<CertificateVerificationResponse>> verify(
            @PathVariable String code
    ) {
        return ResponseEntity.ok(ApiResponse.ok(certificateService.verify(code)));
    }

    public record CertificateIssueRequest(
            @NotNull Long entityId,
            String type
    ) {
    }
}