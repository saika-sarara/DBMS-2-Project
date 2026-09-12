package com.learnova.instructor.service;

import com.learnova.instructor.dto.InstructorRequestResponse;
import com.learnova.instructor.dto.InstructorRequestView;
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

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
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

    @Test
    void listAllMapsJoinedViewRowsIntoResponses() {
        OffsetDateTime requestedAt = OffsetDateTime.parse("2026-09-01T10:00:00Z");

        InstructorRequestView pending = view(3L, 9L, "Averell", "User",
                "averell@example.com", "Please approve me", "PENDING", requestedAt);
        InstructorRequestView approved = view(4L, 10L, "Joe", "Bloggs",
                "joe@example.com", null, "APPROVED", requestedAt.plusDays(1));

        when(instructorRequestRepository.findAllWithUserOrderByCreatedAtDesc())
                .thenReturn(List.of(pending, approved));

        List<InstructorRequestResponse> responses = instructorRequestService.listAll();

        assertEquals(2, responses.size());

        InstructorRequestResponse first = responses.get(0);
        assertEquals(3L, first.getId());
        assertEquals(9L, first.getUserId());
        assertEquals("Averell User", first.getName());
        assertEquals("averell@example.com", first.getEmail());
        assertEquals("Please approve me", first.getNote());
        assertEquals("pending", first.getStatus());
        assertEquals(requestedAt, first.getRequestedAt());
        assertEquals(requestedAt, first.getCreated_at());

        InstructorRequestResponse second = responses.get(1);
        assertEquals(4L, second.getId());
        assertEquals(10L, second.getUserId());
        assertEquals("Joe Bloggs", second.getName());
        assertEquals("joe@example.com", second.getEmail());
        assertNull(second.getNote());
        assertEquals("approved", second.getStatus());
        assertEquals(requestedAt.plusDays(1), second.getRequestedAt());
        assertEquals(requestedAt.plusDays(1), second.getCreated_at());

        verify(instructorRequestRepository).findAllWithUserOrderByCreatedAtDesc();
        verify(userRepository, never()).findById(any());
    }

    @Test
    void listAllThrowsWhenRequestedUserIsMissing() {
        InstructorRequestView orphan = mock(InstructorRequestView.class);
        when(orphan.getEmail()).thenReturn(null);
        when(instructorRequestRepository.findAllWithUserOrderByCreatedAtDesc())
                .thenReturn(List.of(orphan));

        assertThrows(IllegalArgumentException.class, () -> instructorRequestService.listAll());

        verify(userRepository, never()).findById(any());
    }

    private InstructorRequestView view(
            Long id,
            Long userId,
            String firstName,
            String lastName,
            String email,
            String note,
            String status,
            OffsetDateTime requestedAt
    ) {
        InstructorRequestView view = mock(InstructorRequestView.class);
        when(view.getId()).thenReturn(id);
        when(view.getUserId()).thenReturn(userId);
        when(view.getFirstName()).thenReturn(firstName);
        when(view.getLastName()).thenReturn(lastName);
        when(view.getEmail()).thenReturn(email);
        when(view.getNote()).thenReturn(note);
        when(view.getStatus()).thenReturn(status);
        when(view.getRequestedAt()).thenReturn(requestedAt);
        return view;
    }
}