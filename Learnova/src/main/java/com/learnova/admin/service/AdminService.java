package com.learnova.admin.service;

import com.learnova.admin.dto.AdminStatsResponse;
import com.learnova.admin.dto.CreateUserRequest;
import com.learnova.admin.dto.UserManagementResponse;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class AdminService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;

    public AdminService(
            UserRepository userRepository,
            RoleRepository roleRepository,
            PasswordEncoder passwordEncoder,
            JdbcTemplate jdbcTemplate
    ) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public List<UserManagementResponse> listUsers() {
        return userRepository.findAll()
                .stream()
                .sorted(Comparator.comparing(User::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .map(UserManagementResponse::from)
                .toList();
    }

    @Transactional
    public UserManagementResponse createUser(CreateUserRequest request) {
        String email = normalizeEmail(request.getEmail());

        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email is already in use.");
        }

        if (request.getPassword() == null || request.getPassword().length() < 8) {
            throw new IllegalArgumentException("Password must be at least 8 characters.");
        }

        NameParts nameParts = splitName(request.getName());

        User user = new User(
                email,
                passwordEncoder.encode(request.getPassword()),
                nameParts.firstName(),
                nameParts.lastName()
        );

        user.setAccountStatus("ACTIVE");
        user.setRoles(resolveInitialRoles(request.getRole()));

        return UserManagementResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserManagementResponse updateRole(Long userId, String requestedRole) {
        User user = findUser(userId);
        String role = normalizeRole(requestedRole);

        if ("STUDENT".equals(role)) {
            Role student = getRole("STUDENT");
            user.getRoles().removeIf(r -> "INSTRUCTOR".equalsIgnoreCase(r.getName()));
            user.getRoles().add(student);
        } else if ("INSTRUCTOR".equals(role)) {
            user.getRoles().add(getRole("STUDENT"));
            user.getRoles().add(getRole("INSTRUCTOR"));
        } else if ("ADMIN".equals(role)) {
            user.getRoles().add(getRole("ADMIN"));
        }

        return UserManagementResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserManagementResponse updateStatus(Long userId, String frontendStatus) {
        User user = findUser(userId);
        user.setAccountStatus(toDatabaseStatus(frontendStatus));
        return UserManagementResponse.from(userRepository.save(user));
    }

    @Transactional
    public void deleteUser(Long userId) {
        User user = findUser(userId);
        userRepository.delete(user);
    }

    @Transactional(readOnly = true)
    public List<String> listRoles() {
        return roleRepository.findAll()
                .stream()
                .map(Role::getName)
                .map(this::toFrontendRole)
                .toList();
    }

    @Transactional(readOnly = true)
    public AdminStatsResponse stats() {
        long users = safeCount("SELECT COUNT(*) FROM public.users");
        long instructors = safeCount("""
                SELECT COUNT(DISTINCT ur.user_id)
                FROM public.user_roles ur
                JOIN public.roles r ON r.id = ur.role_id
                WHERE r.name = 'INSTRUCTOR'
                """);
        long activeCourses = safeCount("""
                SELECT COUNT(*)
                FROM public.courses
                WHERE status = 'PUBLISHED'
                """);
        long enrollments = safeCount("SELECT COUNT(*) FROM public.enrollments");

        return new AdminStatsResponse(users, instructors, activeCourses, enrollments);
    }

    private User findUser(Long userId) {
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException("Invalid user id.");
        }

        return userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User was not found."));
    }

    private Set<Role> resolveInitialRoles(String requestedRole) {
        String role = normalizeRole(requestedRole);

        Set<Role> roles = new LinkedHashSet<>();

        if ("ADMIN".equals(role)) {
            roles.add(getRole("ADMIN"));
            return roles;
        }

        roles.add(getRole("STUDENT"));

        if ("INSTRUCTOR".equals(role)) {
            roles.add(getRole("INSTRUCTOR"));
        }

        return roles;
    }

    private Role getRole(String roleName) {
        return roleRepository.findByName(roleName)
                .orElseThrow(() -> new IllegalStateException(roleName + " role was not found."));
    }

    private String normalizeRole(String role) {
        if (role == null || role.isBlank()) {
            return "STUDENT";
        }

        String value = role.trim().toUpperCase(Locale.ROOT);

        if ("ADMIN".equals(value)) {
            return "ADMIN";
        }
        if ("INSTRUCTOR".equals(value)) {
            return "INSTRUCTOR";
        }
        return "STUDENT";
    }

    private String toFrontendRole(String role) {
        if ("ADMIN".equalsIgnoreCase(role)) {
            return "Admin";
        }
        if ("INSTRUCTOR".equalsIgnoreCase(role)) {
            return "Instructor";
        }
        return "Student";
    }

    private String toDatabaseStatus(String status) {
        if (status == null || status.isBlank()) {
            return "ACTIVE";
        }

        String value = status.trim().toLowerCase(Locale.ROOT);

        if ("suspended".equals(value)) {
            return "SUSPENDED";
        }
        if ("banned".equals(value) || "disabled".equals(value)) {
            return "BANNED";
        }
        return "ACTIVE";
    }

    private String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("Email is required.");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private NameParts splitName(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            throw new IllegalArgumentException("Name is required.");
        }

        String cleaned = fullName.trim().replaceAll("\\s+", " ");
        String[] parts = cleaned.split(" ", 2);

        String firstName = parts[0];
        String lastName = parts.length > 1 ? parts[1] : "User";

        return new NameParts(firstName, lastName);
    }

    private long safeCount(String sql) {
        try {
            Long count = jdbcTemplate.queryForObject(sql, Long.class);
            return count == null ? 0L : count;
        } catch (DataAccessException ignored) {
            return 0L;
        }
    }

    private record NameParts(String firstName, String lastName) {
    }
}
