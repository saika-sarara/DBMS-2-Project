package com.learnova.admin.service;

import com.learnova.admin.dto.CreateUserRequest;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.security.RoleGrantAuditContext;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
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
}