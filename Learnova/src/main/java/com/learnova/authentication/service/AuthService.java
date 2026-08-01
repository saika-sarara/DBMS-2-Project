package com.learnova.authentication.service;

import com.learnova.authentication.dto.LoginRequest;
import com.learnova.authentication.dto.LoginResponse;
import com.learnova.authentication.dto.RegisterRequest;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthService(UserRepository userRepository, RoleRepository roleRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional
    public String registerUser(RegisterRequest request) {
        String normalizedEmail = request.getEmail().toLowerCase().trim();

        if (userRepository.existsByEmail(normalizedEmail)) {
            throw new RuntimeException("Error: Email is already in use!");
        }

        User user = new User(
                normalizedEmail,
                passwordEncoder.encode(request.getPassword()),
                request.getFullName()
        );

        Set<Role> roles = new HashSet<>();
        Role studentRole = roleRepository.findByName("ROLE_STUDENT")
                .orElseThrow(() -> new RuntimeException("Error: Default Role is not found."));
        roles.add(studentRole);

        user.setRoles(roles);
        userRepository.save(user);

        return "User registered successfully!";
    }

    public LoginResponse loginUser(LoginRequest request) {
        String normalizedEmail = request.getEmail().toLowerCase().trim();

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> new RuntimeException("Error: Invalid email or password!"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Error: Invalid email or password!");
        }

        if (!user.getIsActive()) {
            throw new RuntimeException("Error: Account is deactivated!");
        }

        Set<String> roleNames = user.getRoles().stream()
                .map(Role::getName)
                .collect(Collectors.toSet());

        String dummyToken = "Bearer " + user.getId() + "_" + System.currentTimeMillis();

        return new LoginResponse(dummyToken, user.getEmail(), user.getFullName(), roleNames);
    }
}