package com.learnova.common.exception;

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
}
