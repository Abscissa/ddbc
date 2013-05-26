/**
 * DDBC - D DataBase Connector - abstraction layer for RDBMS access, with interface similar to JDBC. 
 * 
 * Source file ddbc/common.d.
 *
 * DDBC library attempts to provide implementation independent interface to different databases.
 * 
 * Set of supported RDBMSs can be extended by writing Drivers for particular DBs.
 * Currently it only includes MySQL Driver which uses patched version of MYSQLN (native D implementation of MySQL connector, written by Steve Teale)
 * 
 * JDBC documentation can be found here:
 * $(LINK http://docs.oracle.com/javase/1.5.0/docs/api/java/sql/package-summary.html)$(BR)
 *
 * This module contains some useful base class implementations for writing Driver for particular RDBMS.
 * As well it contains useful class - ConnectionPoolDataSourceImpl - which can be used as connection pool.
 *
 * You can find usage examples in unittest{} sections.
 *
 * Copyright: Copyright 2013
 * License:   $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Author:   Vadim Lopatin
 */
module ddbc.common;
import ddbc.core;
import std.algorithm;
import std.exception;
import std.stdio;
import std.conv;
import std.variant;

class DataSourceImpl : DataSource {
    Driver driver;
    string url;
    string[string] params;
    this(Driver driver, string url, string[string]params) {
        this.driver = driver;
        this.url = url;
        this.params = params;
    }
    override Connection getConnection() {
        return driver.connect(url, params);
    }
}

interface ConnectionCloseHandler {
    void onConnectionClosed(Connection connection);
}

class ConnectionWrapper : Connection {
    private ConnectionCloseHandler pool;
    private Connection base;
    private bool closed;

    this(ConnectionCloseHandler pool, Connection base) {
        this.pool = pool;
        this.base = base;
    }
    override void close() { 
        assert(!closed, "Connection is already closed");
        closed = true; 
        pool.onConnectionClosed(base); 
    }
    override PreparedStatement prepareStatement(string query) { return base.prepareStatement(query); }
    override void commit() { base.commit(); }
    override Statement createStatement() { return base.createStatement(); }
    override string getCatalog() { return base.getCatalog(); }
    override bool isClosed() { return closed; }
    override void rollback() { base.rollback(); }
    override bool getAutoCommit() { return base.getAutoCommit(); }
    override void setAutoCommit(bool autoCommit) { base.setAutoCommit(autoCommit); }
    override void setCatalog(string catalog) { base.setCatalog(catalog); }
}
// some bug in std.algorithm.remove? length is not decreased... - under linux x64 dmd
static void myRemove(T)(ref T[] array, size_t index) {
    for (auto i = index; i < array.length - 1; i++) {
        array[i] = array[i + 1];
    }
    array[array.length - 1] = T.init;
    array.length--;
}

// TODO: implement limits
// TODO: thread safety
class ConnectionPoolDataSourceImpl : DataSourceImpl, ConnectionCloseHandler {
private:
    int maxPoolSize;
    int timeToLive;
    int waitTimeOut;

    Connection [] activeConnections;
    Connection [] freeConnections;

public:

    this(Driver driver, string url, string[string]params, int maxPoolSize = 1, int timeToLive = 600, int waitTimeOut = 30) {
        super(driver, url, params);
        this.maxPoolSize = maxPoolSize;
        this.timeToLive = timeToLive;
        this.waitTimeOut = waitTimeOut;
    }

    override Connection getConnection() {
        Connection conn = null;
        //writeln("getConnection(): freeConnections.length = " ~ to!string(freeConnections.length));
        if (freeConnections.length > 0) {
            //writeln("getConnection(): returning free connection");
            conn = freeConnections[freeConnections.length - 1]; // $ - 1
            auto oldSize = freeConnections.length;
            myRemove(freeConnections, freeConnections.length - 1);
            //freeConnections.length = oldSize - 1; // some bug in remove? length is not decreased...
            auto newSize = freeConnections.length;
            assert(newSize == oldSize - 1);
        } else {
            //writeln("getConnection(): creating new connection");
            try {
                conn = super.getConnection();
            } catch (Exception e) {
                //writeln("exception while creating connection " ~ e.msg);
                throw e;
            }
            //writeln("getConnection(): connection created");
        }
        auto oldSize = activeConnections.length;
        activeConnections ~= conn;
        auto newSize = activeConnections.length;
        assert(oldSize == newSize - 1);
        auto wrapper = new ConnectionWrapper(this, conn);
        return wrapper;
    }

    void removeUsed(Connection connection) {
        //writeln("removeUsed");
        //writeln("removeUsed - activeConnections.length=" ~ to!string(activeConnections.length));
        foreach (i, item; activeConnections) {
            if (item == connection) {
                auto oldSize = activeConnections.length;
                //std.algorithm.remove(activeConnections, i);
                myRemove(activeConnections, i);
                //activeConnections.length = oldSize - 1;
                auto newSize = activeConnections.length;
                assert(oldSize == newSize + 1);
                return;
            }
        }
        throw new SQLException("Connection being closed is not found in pool");
    }

    override void onConnectionClosed(Connection connection) {
        //writeln("onConnectionClosed");
        assert(connection !is null);
        //writeln("calling removeUsed");
        removeUsed(connection);
        //writeln("adding to free list");
        auto oldSize = freeConnections.length;
        freeConnections ~= connection;
        auto newSize = freeConnections.length;
        assert(newSize == oldSize + 1);
    }
}

// Helper implementation of ResultSet - throws Method not implemented for most of methods.
class ResultSetImpl : ddbc.core.ResultSet {
public:
    override int opApply(int delegate(DataSetReader) dg) { 
        int result = 0;
        if (!first())
            return 0;
        do { 
            result = dg(cast(DataSetReader)this); 
            if (result) break; 
        } while (next());
        return result; 
    }
    override void close() {
        throw new SQLException("Method not implemented");
    }
    override bool first() {
        throw new SQLException("Method not implemented");
    }
    override bool isFirst() {
        throw new SQLException("Method not implemented");
    }
    override bool isLast() {
        throw new SQLException("Method not implemented");
    }
    override bool next() {
        throw new SQLException("Method not implemented");
    }
    
    override size_t findColumn(string columnName) {
        throw new SQLException("Method not implemented");
    }
    override bool getBoolean(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override bool getBoolean(string columnName) {
        return getBoolean(findColumn(columnName));
    }
    override ubyte getUbyte(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override ubyte getUbyte(string columnName) {
        return getUbyte(findColumn(columnName));
    }
    override byte getByte(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override byte getByte(string columnName) {
        return getByte(findColumn(columnName));
    }
    override byte[] getBytes(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override byte[] getBytes(string columnName) {
        return getBytes(findColumn(columnName));
    }
    override ubyte[] getUbytes(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override ubyte[] getUbytes(string columnName) {
        return getUbytes(findColumn(columnName));
    }
    override short getShort(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override short getShort(string columnName) {
        return getShort(findColumn(columnName));
    }
    override ushort getUshort(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override ushort getUshort(string columnName) {
        return getUshort(findColumn(columnName));
    }
    override int getInt(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override int getInt(string columnName) {
        return getInt(findColumn(columnName));
    }
    override uint getUint(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override uint getUint(string columnName) {
        return getUint(findColumn(columnName));
    }
    override long getLong(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override long getLong(string columnName) {
        return getLong(findColumn(columnName));
    }
    override ulong getUlong(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override ulong getUlong(string columnName) {
        return getUlong(findColumn(columnName));
    }
    override double getDouble(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override double getDouble(string columnName) {
        return getDouble(findColumn(columnName));
    }
    override float getFloat(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override float getFloat(string columnName) {
        return getFloat(findColumn(columnName));
    }
    override string getString(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override string getString(string columnName) {
        return getString(findColumn(columnName));
    }
    override Variant getVariant(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override Variant getVariant(string columnName) {
        return getVariant(findColumn(columnName));
    }

    override bool wasNull() {
        throw new SQLException("Method not implemented");
    }

    override bool isNull(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }

    //Retrieves the number, types and properties of this ResultSet object's columns
    override ResultSetMetaData getMetaData() {
        throw new SQLException("Method not implemented");
    }
    //Retrieves the Statement object that produced this ResultSet object.
    override Statement getStatement() {
        throw new SQLException("Method not implemented");
    }
    //Retrieves the current row number
    override size_t getRow() {
        throw new SQLException("Method not implemented");
    }
    //Retrieves the fetch size for this ResultSet object.
    override size_t getFetchSize() {
        throw new SQLException("Method not implemented");
    }
    override std.datetime.DateTime getDateTime(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override std.datetime.Date getDate(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
    override std.datetime.TimeOfDay getTime(size_t columnIndex) {
        throw new SQLException("Method not implemented");
    }
}

class ColumnMetadataItem {
    string 	catalogName;
    int	    displaySize;
    string 	label;
    string  name;
    int 	type;
    string 	typeName;
    int     precision;
    int     scale;
    string  schemaName;
    string  tableName;
    bool 	isAutoIncrement;
    bool 	isCaseSensitive;
    bool 	isCurrency;
    bool 	isDefinitelyWritable;
    int 	isNullable;
    bool 	isReadOnly;
    bool 	isSearchable;
    bool 	isSigned;
    bool 	isWritable;
}

class ParameterMetaDataItem {
    /// Retrieves the designated parameter's mode.
    int mode;
    /// Retrieves the designated parameter's SQL type.
    int type;
    /// Retrieves the designated parameter's database-specific type name.
    string typeName;
    /// Retrieves the designated parameter's number of decimal digits.
    int precision;
    /// Retrieves the designated parameter's number of digits to right of the decimal point.
    int scale;
    /// Retrieves whether null values are allowed in the designated parameter.
    int isNullable;
    /// Retrieves whether values for the designated parameter can be signed numbers.
    bool isSigned;
}

class ParameterMetaDataImpl : ParameterMetaData {
    ParameterMetaDataItem [] cols;
    this(ParameterMetaDataItem [] cols) {
        this.cols = cols;
    }
    ref ParameterMetaDataItem col(size_t column) {
        enforceEx!SQLException(column >=1 && column <= cols.length, "Parameter index out of range");
        return cols[column - 1];
    }
    // Retrieves the fully-qualified name of the Java class whose instances should be passed to the method PreparedStatement.setObject.
    //String getParameterClassName(int param);
    /// Retrieves the number of parameters in the PreparedStatement object for which this ParameterMetaData object contains information.
    size_t getParameterCount() {
        return cols.length;
    }
    /// Retrieves the designated parameter's mode.
    int getParameterMode(size_t param) { return col(param).mode; }
    /// Retrieves the designated parameter's SQL type.
    int getParameterType(size_t param) { return col(param).type; }
    /// Retrieves the designated parameter's database-specific type name.
    string getParameterTypeName(size_t param) { return col(param).typeName; }
    /// Retrieves the designated parameter's number of decimal digits.
    int getPrecision(size_t param) { return col(param).precision; }
    /// Retrieves the designated parameter's number of digits to right of the decimal point.
    int getScale(size_t param) { return col(param).scale; }
    /// Retrieves whether null values are allowed in the designated parameter.
    int isNullable(size_t param) { return col(param).isNullable; }
    /// Retrieves whether values for the designated parameter can be signed numbers.
    bool isSigned(size_t param) { return col(param).isSigned; }
}

class ResultSetMetaDataImpl : ResultSetMetaData {
    ColumnMetadataItem [] cols;
    this(ColumnMetadataItem [] cols) {
        this.cols = cols;
    }
    ref ColumnMetadataItem col(size_t column) {
        enforceEx!SQLException(column >=1 && column <= cols.length, "Column index out of range");
        return cols[column - 1];
    }
    //Returns the number of columns in this ResultSet object.
    override size_t getColumnCount() { return cols.length; }
    // Gets the designated column's table's catalog name.
    override string getCatalogName(size_t column) { return col(column).catalogName; }
    // Returns the fully-qualified name of the Java class whose instances are manufactured if the method ResultSet.getObject is called to retrieve a value from the column.
    //override string getColumnClassName(size_t column) { return col(column).catalogName; }
    // Indicates the designated column's normal maximum width in characters.
    override int getColumnDisplaySize(size_t column) { return col(column).displaySize; }
    // Gets the designated column's suggested title for use in printouts and displays.
    override string getColumnLabel(size_t column) { return col(column).label; }
    // Get the designated column's name.
    override string getColumnName(size_t column) { return col(column).name; }
    // Retrieves the designated column's SQL type.
    override int getColumnType(size_t column) { return col(column).type; }
    // Retrieves the designated column's database-specific type name.
    override string getColumnTypeName(size_t column) { return col(column).typeName; }
    // Get the designated column's number of decimal digits.
    override int getPrecision(size_t column) { return col(column).precision; }
    // Gets the designated column's number of digits to right of the decimal point.
    override int getScale(size_t column) { return col(column).scale; }
    // Get the designated column's table's schema.
    override string getSchemaName(size_t column) { return col(column).schemaName; }
    // Gets the designated column's table name.
    override string getTableName(size_t column) { return col(column).tableName; }
    // Indicates whether the designated column is automatically numbered, thus read-only.
    override bool isAutoIncrement(size_t column) { return col(column).isAutoIncrement; }
    // Indicates whether a column's case matters.
    override bool isCaseSensitive(size_t column) { return col(column).isCaseSensitive; }
    // Indicates whether the designated column is a cash value.
    override bool isCurrency(size_t column) { return col(column).isCurrency; }
    // Indicates whether a write on the designated column will definitely succeed.
    override bool isDefinitelyWritable(size_t column) { return col(column).isDefinitelyWritable; }
    // Indicates the nullability of values in the designated column.
    override int isNullable(size_t column) { return col(column).isNullable; }
    // Indicates whether the designated column is definitely not writable.
    override bool isReadOnly(size_t column) { return col(column).isReadOnly; }
    // Indicates whether the designated column can be used in a where clause.
    override bool isSearchable(size_t column) { return col(column).isSearchable; }
    // Indicates whether values in the designated column are signed numbers.
    override bool isSigned(size_t column) { return col(column).isSigned; }
    // Indicates whether it is possible for a write on the designated column to succeed.
    override bool isWritable(size_t column) { return col(column).isWritable; }
}

version (unittest) {
    void unitTestExecuteBatch(Connection conn, string[] queries) {
        Statement stmt = conn.createStatement();
        foreach(query; queries) {
            //writeln("query:" ~ query);
            stmt.executeUpdate(query);
        }
    }
}
