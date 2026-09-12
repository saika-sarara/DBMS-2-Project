package com.learnova.admin.service;

import com.learnova.admin.dto.AdminStatsResponse;
import com.learnova.admin.dto.CreateUserRequest;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.security.RoleGrantAuditContext;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.ArgumentMatchers;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.CannotGetJdbcConnectionException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.sql.ResultSet;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private RoleRepository roleRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JdbcTemplate jdbcTemplate;

    @Mock
    private CurrentUserResolver currentUserResolver;

    @Mock
    private RoleGrantAuditContext roleGrantAuditContext;

    @InjectMocks
    private AdminService adminService;

    @Test
    void createUserSetsAuthenticatedActorOnGrant() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(7L);
        when(userRepository.existsByEmail("new@example.com")).thenReturn(false);
        when(passwordEncoder.encode("password123")).thenReturn("encoded");
        when(roleRepository.findByName("STUDENT")).thenReturn(Optional.of(new Role("STUDENT", "x")));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CreateUserRequest request = new CreateUserRequest();
        request.setEmail("new@example.com");
        request.setName("New Person");
        request.setPassword("password123");
        request.setRole("student");

        adminService.createUser(request);

        verify(roleGrantAuditContext).setActor(7L);
    }

    @Test
    void updateRoleSetsAuthenticatedActorOnGrant() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(7L);
        User user = new User("u@example.com", "hash", "Averell", "User");
        when(userRepository.findById(9L)).thenReturn(Optional.of(user));
        when(roleRepository.findByName("STUDENT")).thenReturn(Optional.of(new Role("STUDENT", "x")));
        when(userRepository.save(user)).thenReturn(user);

        adminService.updateRole(9L, "STUDENT");

        verify(roleGrantAuditContext).setActor(7L);
    }

    @Test
    @SuppressWarnings("unchecked")
    void statsRunsOneAggregatedQueryAndMapsAllFourValues() throws Exception {
        ResultSet resultSet = mock(ResultSet.class);
        when(resultSet.getLong("users")).thenReturn(5L);
        when(resultSet.getLong("instructors")).thenReturn(2L);
        when(resultSet.getLong("active_courses")).thenReturn(3L);
        when(resultSet.getLong("enrollments")).thenReturn(7L);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.queryForObject(sqlCaptor.capture(), ArgumentMatchers.<RowMapper<AdminStatsResponse>>any()))
                .thenAnswer(invocation -> {
                    RowMapper<AdminStatsResponse> mapper = invocation.getArgument(1);
                    return mapper.mapRow(resultSet, 0);
                });

        AdminStatsResponse response = adminService.stats();

        assertEquals(5L, response.getUsers());
        assertEquals(2L, response.getInstructors());
        assertEquals(3L, response.getActiveCourses());
        assertEquals(7L, response.getEnrollments());

        String sql = sqlCaptor.getValue();
        assertTrue(sql.contains("public.users"));
        assertTrue(sql.contains("public.user_roles"));
        assertTrue(sql.contains("public.courses"));
        assertTrue(sql.contains("public.enrollments"));

        verify(jdbcTemplate, times(1)).queryForObject(anyString(), ArgumentMatchers.<RowMapper<AdminStatsResponse>>any());
    }

    @Test
    void statsReturnsZeroedResponseWhenAggregatedQueryFails() {
        when(jdbcTemplate.queryForObject(anyString(), ArgumentMatchers.<RowMapper<AdminStatsResponse>>any()))
                .thenThrow(new CannotGetJdbcConnectionException("db unavailable"));

        AdminStatsResponse response = adminService.stats();

        assertEquals(0L, response.getUsers());
        assertEquals(0L, response.getInstructors());
        assertEquals(0L, response.getActiveCourses());
        assertEquals(0L, response.getEnrollments());
    }
}