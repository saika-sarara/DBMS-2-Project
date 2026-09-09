package com.learnova.instructor.service;

import com.learnova.instructor.model.InstructorRequest;
import com.learnova.instructor.repository.InstructorRequestRepository;
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

import java.util.Optional;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InstructorRequestServiceTest {

    @Mock
    private InstructorRequestRepository instructorRequestRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private RoleRepository roleRepository;

    @Mock
    private RoleGrantAuditContext roleGrantAuditContext;

    @InjectMocks
    private InstructorRequestService instructorRequestService;

    @Test
    void approveSetsAdminActorOnGrant() {
        InstructorRequest request = new InstructorRequest(5L, "Please approve me");
        when(instructorRequestRepository.findById(3L)).thenReturn(Optional.of(request));
        User user = new User("u@example.com", "hash", "Averell", "User");
        when(userRepository.findById(5L)).thenReturn(Optional.of(user));
        when(roleRepository.findByName("STUDENT")).thenReturn(Optional.of(new Role("STUDENT", "x")));
        when(roleRepository.findByName("INSTRUCTOR")).thenReturn(Optional.of(new Role("INSTRUCTOR", "x")));
        when(userRepository.save(user)).thenReturn(user);
        when(instructorRequestRepository.save(request)).thenReturn(request);

        instructorRequestService.approve(3L, 7L);

        verify(roleGrantAuditContext).setActor(7L);
    }
}