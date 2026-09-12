package com.learnova.admin.controller;

import com.learnova.admin.dto.AdminStatsResponse;
import com.learnova.admin.dto.UserManagementResponse;
import com.learnova.admin.service.AdminService;
import com.learnova.common.exception.GlobalExceptionHandler;
import com.learnova.instructor.dto.InstructorRequestResponse;
import com.learnova.instructor.service.InstructorRequestService;
import com.learnova.security.UserPrincipal;
import com.learnova.user.model.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AdminControllerTest {

    private AdminService adminService;
    private InstructorRequestService instructorRequestService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        adminService = mock(AdminService.class);
        instructorRequestService = mock(InstructorRequestService.class);

        mockMvc = MockMvcBuilders
                .standaloneSetup(
                        new AdminController(adminService, instructorRequestService)
                )
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void listUsersReturnsUsers() throws Exception {
        UserManagementResponse user = userResponse(7L, "Student User", "student@example.com");
        when(adminService.listUsers()).thenReturn(List.of(user));

        mockMvc.perform(get("/api/v1/admin/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(7))
                .andExpect(jsonPath("$[0].name").value("Student User"))
                .andExpect(jsonPath("$[0].email").value("student@example.com"));

        verify(adminService).listUsers();
    }

    @Test
    void createUserPassesRequestToService() throws Exception {
        UserManagementResponse user = userResponse(8L, "New User", "new@example.com");
        when(adminService.createUser(any())).thenReturn(user);

        mockMvc.perform(
                        post("/api/v1/admin/users")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "name": "New User",
                                          "email": "new@example.com",
                                          "password": "password123",
                                          "role": "student"
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(8))
                .andExpect(jsonPath("$.name").value("New User"));

        verify(adminService).createUser(any());
    }

    @Test
    void updateUserRolePassesUserIdAndRole() throws Exception {
        when(adminService.updateRole(9L, "INSTRUCTOR"))
                .thenReturn(userResponse(9L, "Instructor User", "instructor@example.com"));

        mockMvc.perform(
                        put("/api/v1/admin/users/9/role")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "role": "INSTRUCTOR"
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(9));

        verify(adminService).updateRole(9L, "INSTRUCTOR");
    }

    @Test
    void updateUserStatusPassesUserIdAndStatus() throws Exception {
        when(adminService.updateStatus(10L, "suspended"))
                .thenReturn(userResponse(10L, "Suspended User", "suspended@example.com"));

        mockMvc.perform(
                        put("/api/v1/admin/users/10/status")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "status": "suspended"
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(10));

        verify(adminService).updateStatus(10L, "suspended");
    }

    @Test
    void deleteUserPassesUserId() throws Exception {
        mockMvc.perform(delete("/api/v1/admin/users/11"))
                .andExpect(status().isOk());

        verify(adminService).deleteUser(11L);
    }

    @Test
    void listRolesReturnsAvailableRoles() throws Exception {
        when(adminService.listRoles()).thenReturn(List.of("Admin", "Instructor", "Student"));

        mockMvc.perform(get("/api/v1/admin/roles"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0]").value("Admin"))
                .andExpect(jsonPath("$[2]").value("Student"));

        verify(adminService).listRoles();
    }

    @Test
    void statsReturnsStatistics() throws Exception {
        when(adminService.stats()).thenReturn(new AdminStatsResponse(25, 6, 12, 140));

        mockMvc.perform(get("/api/v1/admin/stats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.users").value(25))
                .andExpect(jsonPath("$.instructors").value(6))
                .andExpect(jsonPath("$.activeCourses").value(12))
                .andExpect(jsonPath("$.enrollments").value(140));

        verify(adminService).stats();
    }

    @Test
    void listInstructorRequestsReturnsRequests() throws Exception {
        when(instructorRequestService.listAll())
                .thenReturn(List.of(mock(InstructorRequestResponse.class)));

        mockMvc.perform(get("/api/v1/admin/instructor-requests"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(1));

        verify(instructorRequestService).listAll();
    }

    @Test
    void approveInstructorRequestUsesAuthenticatedAdminId() throws Exception {
        Authentication authentication = adminAuthentication(42L);
        InstructorRequestResponse response = mock(InstructorRequestResponse.class);
        when(instructorRequestService.approve(12L, 42L)).thenReturn(response);

        mockMvc.perform(
                        post("/api/v1/admin/instructor-requests/12/approve")
                                .principal(authentication)
                )
                .andExpect(status().isOk());

        verify(instructorRequestService).approve(12L, 42L);
    }

    @Test
    void rejectInstructorRequestUsesAuthenticatedAdminId() throws Exception {
        Authentication authentication = adminAuthentication(43L);
        InstructorRequestResponse response = mock(InstructorRequestResponse.class);
        when(instructorRequestService.reject(13L, 43L)).thenReturn(response);

        mockMvc.perform(
                        post("/api/v1/admin/instructor-requests/13/reject")
                                .principal(authentication)
                )
                .andExpect(status().isOk());

        verify(instructorRequestService).reject(13L, 43L);
    }

    private UserManagementResponse userResponse(Long id, String name, String email) {
        UserManagementResponse response = new UserManagementResponse();
        response.setId(id);
        response.setName(name);
        response.setEmail(email);
        return response;
    }

    private Authentication adminAuthentication(Long adminId) {
        User admin = new User("admin@example.com", "hash", "Admin", "User");
        admin.setId(adminId);

        Authentication authentication = mock(Authentication.class);
        when(authentication.getPrincipal()).thenReturn(new UserPrincipal(admin));
        return authentication;
    }
}
