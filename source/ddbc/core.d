/**
 * DDBC - D DataBase Connector - abstraction layer for RDBMS access, with interface similar to JDBC. 
 * 
 * Source file ddbc/core.d.
 *
 * DDBC library attempts to provide implementation independent interface to different databases.
 * 
 * Set of supported RDBMSs can be extended by writing Drivers for particular DBs.
 * Currently it only includes MySQL Driver which uses patched version of MYSQLN (native D implementation of MySQL connector, written by Steve Teale)
 * 
 * JDBC documentation can be found here:
 * $(LINK http://docs.oracle.com/javase/1.5.0/docs/api/java/sql/package-summary.html)$(BR)
 *
 * Limitations of current version: readonly unidirectional resultset, completely fetched into memory.
 * 
 * Its primary objects are:
 * $(UL
 *    $(LI Driver: $(UL $(LI Implements interface to particular RDBMS, used to create connections)))
 *    $(LI Connection: $(UL $(LI Connection to the server, and querying and setting of server parameters.)))
 *    $(LI Statement: Handling of general SQL requests/queries/commands, with principal methods:
 *       $(UL $(LI executeUpdate() - run query which doesn't return result set.)
 *            $(LI executeQuery() - execute query which returns ResultSet interface to access rows of result.)
 *        )
 *    )
 *    $(LI PreparedStatement: Handling of general SQL requests/queries/commands which having additional parameters, with principal methods:
 *       $(UL $(LI executeUpdate() - run query which doesn't return result set.)
 *            $(LI executeQuery() - execute query which returns ResultSet interface to access rows of result.)
 *            $(LI setXXX() - setter methods to bind parameters.)
 *        )
 *    )
 *    $(LI ResultSet: $(UL $(LI Get result of query row by row, accessing individual fields.)))
 * )
 *
 * You can find usage examples in unittest{} sections.
 *
 * Copyright: Copyright 2013
 * License:   $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Author:   Vadim Lopatin
 */
module ddbc.core;

import std.exception;
import std.variant;
import std.datetime;

class SQLException : Exception {
    this(string msg, string f = __FILE__, size_t l = __LINE__) { super(msg, f, l); }
    this(Exception causedBy, string f = __FILE__, size_t l = __LINE__) { super(causedBy.msg, f, l); }
}

/// JDBC java.sql.Types from http://docs.oracle.com/javase/6/docs/api/java/sql/Types.html
enum SqlType {
    //sometimes referred to as a type code, that identifies the generic SQL type ARRAY.
    //ARRAY,
    ///sometimes referred to as a type code, that identifies the generic SQL type BIGINT.
    BIGINT,
    ///sometimes referred to as a type code, that identifies the generic SQL type BINARY.
    //BINARY,
    //sometimes referred to as a type code, that identifies the generic SQL type BIT.
    BIT,
    ///sometimes referred to as a type code, that identifies the generic SQL type BLOB.
    BLOB,
    ///somtimes referred to as a type code, that identifies the generic SQL type BOOLEAN.
    BOOLEAN,
    ///sometimes referred to as a type code, that identifies the generic SQL type CHAR.
    CHAR,
    ///sometimes referred to as a type code, that identifies the generic SQL type CLOB.
    CLOB,
    //somtimes referred to as a type code, that identifies the generic SQL type DATALINK.
    //DATALINK,
    ///sometimes referred to as a type code, that identifies the generic SQL type DATE.
    DATE,
    ///sometimes referred to as a type code, that identifies the generic SQL type DATETIME.
    DATETIME,
    ///sometimes referred to as a type code, that identifies the generic SQL type DECIMAL.
    DECIMAL,
    //sometimes referred to as a type code, that identifies the generic SQL type DISTINCT.
    //DISTINCT,
    ///sometimes referred to as a type code, that identifies the generic SQL type DOUBLE.
    DOUBLE,
    ///sometimes referred to as a type code, that identifies the generic SQL type FLOAT.
    FLOAT,
    ///sometimes referred to as a type code, that identifies the generic SQL type INTEGER.
    INTEGER,
    //sometimes referred to as a type code, that identifies the generic SQL type JAVA_OBJECT.
    //JAVA_OBJECT,
    ///sometimes referred to as a type code, that identifies the generic SQL type LONGNVARCHAR.
    LONGNVARCHAR,
    ///sometimes referred to as a type code, that identifies the generic SQL type LONGVARBINARY.
    LONGVARBINARY,
    ///sometimes referred to as a type code, that identifies the generic SQL type LONGVARCHAR.
    LONGVARCHAR,
    ///sometimes referred to as a type code, that identifies the generic SQL type NCHAR
    NCHAR,
    ///sometimes referred to as a type code, that identifies the generic SQL type NCLOB.
    NCLOB,
    ///The constant in the Java programming language that identifies the generic SQL value NULL.
    NULL,
    ///sometimes referred to as a type code, that identifies the generic SQL type NUMERIC.
    NUMERIC,
    ///sometimes referred to as a type code, that identifies the generic SQL type NVARCHAR.
    NVARCHAR,
    ///indicates that the SQL type is database-specific and gets mapped to a object that can be accessed via the methods getObject and setObject.
    OTHER,
    //sometimes referred to as a type code, that identifies the generic SQL type REAL.
    //REAL,
    //sometimes referred to as a type code, that identifies the generic SQL type REF.
    //REF,
    //sometimes referred to as a type code, that identifies the generic SQL type ROWID
    //ROWID,
    ///sometimes referred to as a type code, that identifies the generic SQL type SMALLINT.
    SMALLINT,
    //sometimes referred to as a type code, that identifies the generic SQL type XML.
    //SQLXML,
    //sometimes referred to as a type code, that identifies the generic SQL type STRUCT.
    //STRUCT,
    ///sometimes referred to as a type code, that identifies the generic SQL type TIME.
    TIME,
    //sometimes referred to as a type code, that identifies the generic SQL type TIMESTAMP.
    //TIMESTAMP,
    ///sometimes referred to as a type code, that identifies the generic SQL type TINYINT.
    TINYINT,
    ///sometimes referred to as a type code, that identifies the generic SQL type VARBINARY.
    VARBINARY,
    ///sometimes referred to as a type code, that identifies the generic SQL type VARCHAR.
    VARCHAR,
}

interface Connection {
    /// Releases this Connection object's database and JDBC resources immediately instead of waiting for them to be automatically released.
    void close();
    /// Makes all changes made since the previous commit/rollback permanent and releases any database locks currently held by this Connection object.
    void commit();
    /// Retrieves this Connection object's current catalog name.
    string getCatalog();
    /// Sets the given catalog name in order to select a subspace of this Connection object's database in which to work.
    void setCatalog(string catalog);
    /// Retrieves whether this Connection object has been closed.
    bool isClosed();
    /// Undoes all changes made in the current transaction and releases any database locks currently held by this Connection object.
    void rollback();
    /// Retrieves the current auto-commit mode for this Connection object.
    bool getAutoCommit();
    /// Sets this connection's auto-commit mode to the given state.
    void setAutoCommit(bool autoCommit);
    // statements
    /// Creates a Statement object for sending SQL statements to the database.
    Statement createStatement();
    /// Creates a PreparedStatement object for sending parameterized SQL statements to the database.
    PreparedStatement prepareStatement(string query);
}

interface ResultSetMetaData {
    //Returns the number of columns in this ResultSet object.
    size_t getColumnCount();

    // Gets the designated column's table's catalog name.
    string getCatalogName(size_t column);
    // Returns the fully-qualified name of the Java class whose instances are manufactured if the method ResultSet.getObject is called to retrieve a value from the column.
    //string getColumnClassName(int column);
    // Indicates the designated column's normal maximum width in characters.
    int getColumnDisplaySize(size_t column);
    // Gets the designated column's suggested title for use in printouts and displays.
    string getColumnLabel(size_t column);
    // Get the designated column's name.
    string getColumnName(size_t column);
    // Retrieves the designated column's SQL type.
    int getColumnType(size_t column);
    // Retrieves the designated column's database-specific type name.
    string getColumnTypeName(size_t column);
    // Get the designated column's number of decimal digits.
    int getPrecision(size_t column);
    // Gets the designated column's number of digits to right of the decimal point.
    int getScale(size_t column);
    // Get the designated column's table's schema.
    string getSchemaName(size_t column);
    // Gets the designated column's table name.
    string getTableName(size_t column);
    // Indicates whether the designated column is automatically numbered, thus read-only.
    bool isAutoIncrement(size_t column);
    // Indicates whether a column's case matters.
    bool isCaseSensitive(size_t column);
    // Indicates whether the designated column is a cash value.
    bool isCurrency(size_t column);
    // Indicates whether a write on the designated column will definitely succeed.
    bool isDefinitelyWritable(size_t column);
    // Indicates the nullability of values in the designated column.
    int isNullable(size_t column);
    // Indicates whether the designated column is definitely not writable.
    bool isReadOnly(size_t column);
    // Indicates whether the designated column can be used in a where clause.
    bool isSearchable(size_t column);
    // Indicates whether values in the designated column are signed numbers.
    bool isSigned(size_t column);
    // Indicates whether it is possible for a write on the designated column to succeed.
    bool isWritable(size_t column);
}

interface ParameterMetaData {
    // Retrieves the fully-qualified name of the Java class whose instances should be passed to the method PreparedStatement.setObject.
    //String getParameterClassName(size_t param);
    /// Retrieves the number of parameters in the PreparedStatement object for which this ParameterMetaData object contains information.
    size_t getParameterCount();
    /// Retrieves the designated parameter's mode.
    int getParameterMode(size_t param);
    /// Retrieves the designated parameter's SQL type.
    int getParameterType(size_t param);
    /// Retrieves the designated parameter's database-specific type name.
    string getParameterTypeName(size_t param);
    /// Retrieves the designated parameter's number of decimal digits.
    int getPrecision(size_t param);
    /// Retrieves the designated parameter's number of digits to right of the decimal point.
    int getScale(size_t param);
    /// Retrieves whether null values are allowed in the designated parameter.
    int isNullable(size_t param);
    /// Retrieves whether values for the designated parameter can be signed numbers.
    bool isSigned(size_t param);
}

interface DataSetReader {
    bool getBoolean(size_t columnIndex);
    ubyte getUbyte(size_t columnIndex);
    ubyte[] getUbytes(size_t columnIndex);
    byte[] getBytes(size_t columnIndex);
    byte getByte(size_t columnIndex);
    short getShort(size_t columnIndex);
    ushort getUshort(size_t columnIndex);
    int getInt(size_t columnIndex);
    uint getUint(size_t columnIndex);
    long getLong(size_t columnIndex);
    ulong getUlong(size_t columnIndex);
    double getDouble(size_t columnIndex);
    float getFloat(size_t columnIndex);
    string getString(size_t columnIndex);
    DateTime getDateTime(size_t columnIndex);
    Date getDate(size_t columnIndex);
    TimeOfDay getTime(size_t columnIndex);
    Variant getVariant(size_t columnIndex);
    bool isNull(size_t columnIndex);
    bool wasNull();
}

interface DataSetWriter {
    void setFloat(size_t parameterIndex, float x);
    void setDouble(size_t parameterIndex, double x);
    void setBoolean(size_t parameterIndex, bool x);
    void setLong(size_t parameterIndex, long x);
    void setInt(size_t parameterIndex, int x);
    void setShort(size_t parameterIndex, short x);
    void setByte(size_t parameterIndex, byte x);
    void setBytes(size_t parameterIndex, byte[] x);
    void setUlong(size_t parameterIndex, ulong x);
    void setUint(size_t parameterIndex, uint x);
    void setUshort(size_t parameterIndex, ushort x);
    void setUbyte(size_t parameterIndex, ubyte x);
    void setUbytes(size_t parameterIndex, ubyte[] x);
    void setString(size_t parameterIndex, string x);
    void setDateTime(size_t parameterIndex, DateTime x);
    void setDate(size_t parameterIndex, Date x);
    void setTime(size_t parameterIndex, TimeOfDay x);
    void setVariant(size_t columnIndex, Variant x);

    void setNull(size_t parameterIndex);
    void setNull(size_t parameterIndex, int sqlType);
}

interface ResultSet : DataSetReader {
    void close();
    bool first();
    bool isFirst();
    bool isLast();
    bool next();

    //Retrieves the number, types and properties of this ResultSet object's columns
    ResultSetMetaData getMetaData();
    //Retrieves the Statement object that produced this ResultSet object.
    Statement getStatement();
    //Retrieves the current row number
    size_t getRow();
    //Retrieves the fetch size for this ResultSet object.
    size_t getFetchSize();

    // from DataSetReader
    bool getBoolean(size_t columnIndex);
    ubyte getUbyte(size_t columnIndex);
    ubyte[] getUbytes(size_t columnIndex);
    byte[] getBytes(size_t columnIndex);
    byte getByte(size_t columnIndex);
    short getShort(size_t columnIndex);
    ushort getUshort(size_t columnIndex);
    int getInt(size_t columnIndex);
    uint getUint(size_t columnIndex);
    long getLong(size_t columnIndex);
    ulong getUlong(size_t columnIndex);
    double getDouble(size_t columnIndex);
    float getFloat(size_t columnIndex);
    string getString(size_t columnIndex);
    Variant getVariant(size_t columnIndex);

    bool isNull(size_t columnIndex);
    bool wasNull();

    // additional methods
    size_t findColumn(string columnName);
    bool getBoolean(string columnName);
    ubyte getUbyte(string columnName);
    ubyte[] getUbytes(string columnName);
    byte[] getBytes(string columnName);
    byte getByte(string columnName);
    short getShort(string columnName);
    ushort getUshort(string columnName);
    int getInt(string columnName);
    uint getUint(string columnName);
    long getLong(string columnName);
    ulong getUlong(string columnName);
    double getDouble(string columnName);
    float getFloat(string columnName);
    string getString(string columnName);
    DateTime getDateTime(size_t columnIndex);
    Date getDate(size_t columnIndex);
    TimeOfDay getTime(size_t columnIndex);
    Variant getVariant(string columnName);

    /// to iterate through all rows in result set
    int opApply(int delegate(DataSetReader) dg);

}

interface Statement {
    ResultSet executeQuery(string query);
    ulong executeUpdate(string query);
    ulong executeUpdate(string query, out Variant insertId);
    void close();
}

/// An object that represents a precompiled SQL statement. 
interface PreparedStatement : Statement, DataSetWriter {
    /// Executes the SQL statement in this PreparedStatement object, which must be an SQL INSERT, UPDATE or DELETE statement; or an SQL statement that returns nothing, such as a DDL statement.
    ulong executeUpdate();
    /// Executes the SQL statement in this PreparedStatement object, which must be an SQL INSERT, UPDATE or DELETE statement; or an SQL statement that returns nothing, such as a DDL statement.
    ulong executeUpdate(out Variant insertId);
    /// Executes the SQL query in this PreparedStatement object and returns the ResultSet object generated by the query.
    ResultSet executeQuery();

    /// Retrieves a ResultSetMetaData object that contains information about the columns of the ResultSet object that will be returned when this PreparedStatement object is executed.
    ResultSetMetaData getMetaData();
    /// Retrieves the number, types and properties of this PreparedStatement object's parameters.
    ParameterMetaData getParameterMetaData();
    /// Clears the current parameter values immediately.
    void clearParameters();

    // from DataSetWriter
    void setFloat(size_t parameterIndex, float x);
    void setDouble(size_t parameterIndex, double x);
    void setBoolean(size_t parameterIndex, bool x);
    void setLong(size_t parameterIndex, long x);
    void setInt(size_t parameterIndex, int x);
    void setShort(size_t parameterIndex, short x);
    void setByte(size_t parameterIndex, byte x);
    void setBytes(size_t parameterIndex, byte[] x);
    void setUlong(size_t parameterIndex, ulong x);
    void setUint(size_t parameterIndex, uint x);
    void setUshort(size_t parameterIndex, ushort x);
    void setUbyte(size_t parameterIndex, ubyte x);
    void setUbytes(size_t parameterIndex, ubyte[] x);
    void setString(size_t parameterIndex, string x);
    void setDateTime(size_t parameterIndex, DateTime x);
    void setDate(size_t parameterIndex, Date x);
    void setTime(size_t parameterIndex, TimeOfDay x);
    void setVariant(size_t parameterIndex, Variant x);

    void setNull(size_t parameterIndex);
    void setNull(size_t parameterIndex, int sqlType);
}

interface Driver {
    Connection connect(string url, string[string] params);
}

interface DataSource {
    Connection getConnection();
}
