public class TestUpdateInsert {
    
    public void testUpdateStatement() {
        // UPDATE statement with SET and WHERE clauses
        sqlBuf.append("UPDATE ").append(TableNames.USERS).append(" SET ");
        sqlBuf.append("USER_NAME = ?, EMAIL = ?, UPDATED_DATE = SYSDATE ");
        sqlBuf.append("WHERE USER_ID = ? AND STATUS = ?");
    }
    
    public void testInsertStatement() {
        // INSERT statement
        sqlBuf.append("INSERT INTO ").append(TableNames.USERS).append(" ");
        sqlBuf.append("(USER_ID, USER_NAME, EMAIL, CREATED_DATE) ");
        sqlBuf.append("VALUES (?, ?, ?, SYSDATE)");
    }
    
    public void testMultiLineUpdate() {
        // Multi-line UPDATE statement
        sqlBuf.append("UPDATE ").append(TableNames.USERS).append(" SET ");
        sqlBuf.append(
            "USER_NAME = ?, EMAIL = ?, PHONE = ?, " +
            "ADDRESS = ?, UPDATED_DATE = SYSDATE ");
        sqlBuf.append("WHERE USER_ID = ? AND STATUS = ?");
    }
}
