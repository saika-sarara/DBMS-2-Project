package com.learnova.security;

import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.io.Serializable;
import java.util.Collection;
import java.util.Set;
import java.util.stream.Collectors;

public class UserPrincipal implements UserDetails, Serializable {

    private static final long serialVersionUID = 1L;

    private final Long id;
    private final String accountStatus;
    private final Set<String> roleNames;

    public UserPrincipal(User user) {
        this(
                user.getId(),
                user.getAccountStatus(),
                user.getRoles()
                        .stream()
                        .map(Role::getName)
                        .collect(Collectors.toSet())
        );
    }

    public UserPrincipal(Long id, String accountStatus, Set<String> roleNames) {
        this.id = id;
        this.accountStatus = accountStatus;
        this.roleNames = roleNames == null ? Set.of() : Set.copyOf(roleNames);
    }

    public Long getId() {
        return id;
    }

    public Set<String> getRoleNames() {
        return roleNames;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roleNames
                .stream()
                .map(name -> new SimpleGrantedAuthority("ROLE_" + name))
                .collect(Collectors.toSet());
    }

    @Override
    public String getPassword() {
        return null;
    }

    @Override
    public String getUsername() {
        return String.valueOf(id);
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return !"SUSPENDED".equalsIgnoreCase(accountStatus);
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return "ACTIVE".equalsIgnoreCase(accountStatus);
    }
}