def mysql_conn(host_name:, user:, pass:, database:)
  Mysql2::Client.new(host: host_name, username: user, password: pass, database: database)
end

### Database level methods
def database_drop_query
  %(DROP DATABASE IF EXISTS authorized_headings)
end

def database_create_query
  %(CREATE DATABASE IF NOT EXISTS authorized_headings)
end

def use_db_name_query
  %(
    USE authorized_headings
  )
end

def use_db_name_command(conn)
  conn.query(use_db_name_query)
end

def create_auth_database(conn)
  conn.query(database_drop_query)
  conn.query(database_create_query)
  use_db_name_command(conn)
end

### Table creation
def heading_table_create_query(table_name)
  %(CREATE TABLE IF NOT EXISTS #{table_name}
    \(
      heading_id INT PRIMARY KEY AUTO_INCREMENT,
      heading VARCHAR(1024),
      lccn VARCHAR(30)
    \)
  )
end

def create_lcsh_tables(conn)
  use_db_name_command(conn)
  conn.query("DROP TABLE IF EXISTS #{LCSH_HEADING_TABLE_NAME}")
  conn.query("DROP TABLE IF EXISTS #{LCSH_VARIANT_TABLE_NAME}")
  conn.query(heading_table_create_query(LCSH_HEADING_TABLE_NAME))
  conn.query(heading_table_create_query(LCSH_VARIANT_TABLE_NAME))
  conn.query("CREATE INDEX lcsh_authorized ON #{LCSH_HEADING_TABLE_NAME} (heading)")
  conn.query("CREATE INDEX lcsh_variant ON #{LCSH_VARIANT_TABLE_NAME} (heading)")
end

def create_naf_tables(conn)
  use_db_name_command(conn)
  conn.query("DROP TABLE IF EXISTS #{NAF_HEADING_TABLE_NAME}")
  conn.query("DROP TABLE IF EXISTS #{NAF_VARIANT_TABLE_NAME}")
  conn.query(heading_table_create_query(NAF_HEADING_TABLE_NAME))
  conn.query(heading_table_create_query(NAF_VARIANT_TABLE_NAME))
  conn.query("CREATE INDEX naf_authorized ON #{NAF_HEADING_TABLE_NAME} (heading)")
  conn.query("CREATE INDEX naf_variant ON #{NAF_VARIANT_TABLE_NAME} (heading)")
end

def heading_string_table_create_query(table_name)
  %(CREATE TABLE IF NOT EXISTS #{table_name}
    \(
      string_id INT PRIMARY KEY AUTO_INCREMENT,
      uri VARCHAR(255),
      heading_string VARCHAR(255)
    \)
  )
end

def create_lcgft_tables(conn)
  use_db_name_command(conn)
  conn.query("DROP TABLE IF EXISTS #{LCGFT_HEADING_TABLE_NAME}")
  conn.query("DROP TABLE IF EXISTS #{LCGFT_VARIANT_TABLE_NAME}")
  conn.query("DROP TABLE IF EXISTS #{LCGFT_HEADING_STRING_TABLE_NAME}")
  conn.query(heading_table_create_query(LCGFT_HEADING_TABLE_NAME))
  conn.query(heading_table_create_query(LCGFT_VARIANT_TABLE_NAME))
  conn.query(heading_string_table_create_query(LCGFT_HEADING_STRING_TABLE_NAME))
  conn.query("CREATE INDEX lcgft_authorized ON #{LCGFT_HEADING_TABLE_NAME} (heading)")
  conn.query("CREATE INDEX lcgft_variant ON #{LCGFT_VARIANT_TABLE_NAME} (heading)")
  conn.query("CREATE INDEX lcgft_uri ON #{LCGFT_HEADING_STRING_TABLE_NAME} (heading_string)")
end

def lccn_marc_table_create_query
  %(CREATE TABLE IF NOT EXISTS lccn_to_marc
    \(
      marc_id INT PRIMARY KEY AUTO_INCREMENT,
      lccn VARCHAR(30),
      tag CHAR(3),
      indicators CHAR(2),
      subfields VARCHAR(3000)
    \)
  )
end

### A table that has LCCNs as authority identifiers and a representation of the
###   1xx field from the MARC record
def create_lccn_marc_table(conn)
  use_db_name_command(conn)
  conn.query('DROP TABLE IF EXISTS lccn_to_marc')
  conn.query(lccn_marc_table_create_query)
  conn.query('CREATE INDEX lccn_marc ON lccn_to_marc (lccn)')
end

def lccn_uri_table_create_query
  %(CREATE TABLE IF NOT EXISTS lccn_to_uri
    \(
      uri_id INT PRIMARY KEY AUTO_INCREMENT,
      lccn VARCHAR(30),
      uri VARCHAR(255)
    \)
  )
end

### A table that connects an authority's LCCN with its id.loc.gov URI
def create_lccn_uri_table(conn)
  conn.query('DROP TABLE IF EXISTS lccn_to_uri')
  conn.query(lccn_uri_table_create_query)
  conn.query('CREATE INDEX lccn_uri ON lccn_to_uri (lccn)')
end
