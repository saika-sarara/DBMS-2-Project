package com.learnova.common.exception;

import org.springframework.dao.DataAccessException;

import java.sql.SQLException;

/**
 * A database-raised error forwarded verbatim to the client.
 *
 * The database owns every enrollment business rule and raises stable
 * LTxxx error codes. This layer does NOT interpret those codes; it only
 * carries the PostgreSQL SQLSTATE and the database message so the client
 * receives exactly what the database said.
 */
public class DatabaseException extends RuntimeException {

    private final String sqlState;

    public DatabaseException(String sqlState, String message) {
        super(message);
        this.sqlState = sqlState;
    }

    public String getSqlState() {
        return sqlState;
    }

    public static DatabaseException from(DataAccessException ex) {
        Throwable cause = ex.getMostSpecificCause();
        if (cause instanceof SQLException sqlEx) {
            return new DatabaseException(sqlEx.getSQLState(), sqlEx.getMessage());
        }
        return new DatabaseException(null, "Database error: " + ex.getMessage());
    }
}
