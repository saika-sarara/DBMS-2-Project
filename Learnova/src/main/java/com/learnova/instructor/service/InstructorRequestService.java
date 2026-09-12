package com.learnova.instructor.service;

import com.learnova.instructor.dto.InstructorRequestCreateRequest;
import com.learnova.instructor.dto.InstructorRequestResponse;
import com.learnova.instructor.dto.InstructorRequestView;
import com.learnova.instructor.model.InstructorRequest;
import com.learnova.instructor.repository.InstructorRequestRepository;
import com.learnova.security.RoleGrantAuditContext;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class InstructorRequestService {

    private final InstructorRequestRepository instructorRequestRepository;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final RoleGrantAuditContext roleGrantAuditContext;

    public InstructorRequestService(
            InstructorRequestRepository instructorRequestRepository,
            UserRepository userRepository,
            RoleRepository roleRepository,
            RoleGrantAuditContext roleGrantAuditContext
    ) {
        this.instructorRequestRepository = instructorRequestRepository;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.roleGrantAuditContext = roleGrantAuditContext;
    }

    @Transactional(readOnly = true)
    public List<InstructorRequestResponse> listAll() {
        return instructorRequestRepository.findAllWithUserOrderByCreatedAtDesc()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public InstructorRequestResponse mine(Long userId) {
        return instructorRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(userId)
                .map(this::toResponse)
                .orElse(null);
    }

    @Transactional
    public InstructorRequestResponse create(Long userId, InstructorRequestCreateRequest request) {
        User user = findUser(userId);

        boolean alreadyInstructor = user.getRoles()
                .stream()
                .anyMatch(role -> "INSTRUCTOR".equalsIgnoreCase(role.getName()));

        if (alreadyInstructor) {
            throw new IllegalArgumentException("You already have Instructor access.");
        }

        if (instructorRequestRepository.existsByUserIdAndStatus(userId, "PENDING")) {
            throw new IllegalArgumentException("You already have a pending instructor request.");
        }

        String note = request == null || request.getNote() == null
                ? ""
                : request.getNote().trim();

        InstructorRequest saved = instructorRequestRepository.save(
                new InstructorRequest(userId, note)
        );

        return toResponse(saved);
    }

    @Transactional
    public InstructorRequestResponse approve(Long requestId, Long adminId) {
        roleGrantAuditContext.setActor(adminId);

        InstructorRequest request = findRequest(requestId);
        User user = findUser(request.getUserId());

        Role student = getRole("STUDENT");
        Role instructor = getRole("INSTRUCTOR");

        user.getRoles().add(student);
        user.getRoles().add(instructor);

        request.approve(adminId);

        userRepository.save(user);
        InstructorRequest saved = instructorRequestRepository.save(request);

        return toResponse(saved);
    }

    @Transactional
    public InstructorRequestResponse reject(Long requestId, Long adminId) {
        InstructorRequest request = findRequest(requestId);
        request.reject(adminId, "Rejected by admin.");
        return toResponse(instructorRequestRepository.save(request));
    }

    private InstructorRequestResponse toResponse(InstructorRequest request) {
        User user = findUser(request.getUserId());
        return InstructorRequestResponse.from(request, user);
    }

    private InstructorRequestResponse toResponse(InstructorRequestView view) {
        if (view.getEmail() == null) {
            throw new IllegalArgumentException("User was not found.");
        }
        return InstructorRequestResponse.fromView(view);
    }

    private InstructorRequest findRequest(Long requestId) {
        return instructorRequestRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("Instructor request was not found."));
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User was not found."));
    }

    private Role getRole(String roleName) {
        return roleRepository.findByName(roleName)
                .orElseThrow(() -> new IllegalStateException(roleName + " role was not found."));
    }
}
