package com.learnova.security;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.hibernate.Session;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class RoleGrantAuditContext {

    @PersistenceContext
    private EntityManager entityManager;

    @Transactional
    public void setActor(Long actorId) {
        if (actorId == null) {
            return;
        }

        entityManager.unwrap(Session.class).doWork(connection -> {
            try (java.sql.PreparedStatement statement =
                         connection.prepareStatement("SET LOCAL app.user_id = ?")) {
                statement.setLong(1, actorId);
                statement.executeUpdate();
            }
        });
    }
}