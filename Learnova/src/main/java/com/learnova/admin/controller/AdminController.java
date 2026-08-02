package com.learnova.admin.controller;

import com.learnova.admin.dto.AdminStatsResponse;
import com.learnova.admin.dto.CreateUserRequest;
import com.learnova.admin.dto.RoleAssignmentRequest;
import com.learnova.admin.dto.UserManagementResponse;
import com.learnova.admin.service.AdminService;
import com.learnova.instructor.dto.InstructorRequestResponse;
import com.learnova.instructor.service.InstructorRequestService;
import com.learnova.security.UserPrincipal;
import com.learnova.user.dto.UserStatusUpdateRequest;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    private final AdminService adminService;
    private final InstructorRequestService instructorRequestService;

    public AdminController(
            AdminService adminService,
            InstructorRequestService instructorRequestService
    ) {
        this.adminService = adminService;
        this.instructorRequestService = instructorRequestService;
    }

    @GetMapping("/users")
    public List<UserManagementResponse> listUsers() {
        return adminService.listUsers();
    }

    @PostMapping("/users")
    public UserManagementResponse createUser(@RequestBody CreateUserRequest request) {
        return adminService.createUser(request);
    }

    @PutMapping("/users/{userId}/role")
    public UserManagementResponse updateUserRole(
            @PathVariable Long userId,
            @RequestBody RoleAssignmentRequest request
    ) {
        return adminService.updateRole(userId, request.getRole());
    }

    @PutMapping("/users/{userId}/status")
    public UserManagementResponse updateUserStatus(
            @PathVariable Long userId,
            @RequestBody UserStatusUpdateRequest request
    ) {
        return adminService.updateStatus(userId, request.getStatus());
    }

    @DeleteMapping("/users/{userId}")
    public void deleteUser(@PathVariable Long userId) {
        adminService.deleteUser(userId);
    }

    @GetMapping("/roles")
    public List<String> listRoles() {
        return adminService.listRoles();
    }

    @GetMapping("/stats")
    public AdminStatsResponse stats() {
        return adminService.stats();
    }

    @GetMapping("/instructor-requests")
    public List<InstructorRequestResponse> listInstructorRequests() {
        return instructorRequestService.listAll();
    }

    @PostMapping("/instructor-requests/{requestId}/approve")
    public InstructorRequestResponse approveInstructorRequest(
            @PathVariable Long requestId,
            Authentication authentication
    ) {
        return instructorRequestService.approve(requestId, currentUserId(authentication));
    }

    @PostMapping("/instructor-requests/{requestId}/reject")
    public InstructorRequestResponse rejectInstructorRequest(
            @PathVariable Long requestId,
            Authentication authentication
    ) {
        return instructorRequestService.reject(requestId, currentUserId(authentication));
    }

    private Long currentUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();

        if (principal instanceof UserPrincipal userPrincipal) {
            return userPrincipal.getId();
        }

        throw new IllegalArgumentException("Authenticated admin was not found.");
    }
}
