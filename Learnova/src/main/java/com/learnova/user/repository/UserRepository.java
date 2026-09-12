package com.learnova.user.repository;

import com.learnova.user.dto.UserAuthView;
import com.learnova.user.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    Boolean existsByEmail(String email);

    @Query("""
            SELECT u.id AS id,
                   u.accountStatus AS accountStatus,
                   r.name AS roleName
            FROM User u
            LEFT JOIN u.roles r
            WHERE u.id = :userId
            """)
    List<UserAuthView> findAuthViewsByUserId(@Param("userId") Long userId);
}