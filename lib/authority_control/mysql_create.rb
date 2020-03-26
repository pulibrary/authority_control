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


### Table names
def lcsh_heading_table_name
  'lcsh_headings'
end

def lcsh_variant_table_name
  'lcsh_variants'
end

def naf_heading_table_name
  'naf_headings'
end

def naf_variant_table_name
  'naf_variants'
end

def lcgft_heading_table_name
  'lcgft_headings'
end

def lcgft_variant_table_name
  'lcgft_variants'
end

def lcgft_heading_string_table_name
  'lcgft_heading_strings'
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
  conn.query("DROP TABLE IF EXISTS #{lcsh_heading_table_name}")
  conn.query("DROP TABLE IF EXISTS #{lcsh_variant_table_name}")
  conn.query(heading_table_create_query(lcsh_heading_table_name))
  conn.query(heading_table_create_query(lcsh_variant_table_name))
  conn.query("CREATE INDEX lcsh_authorized ON #{lcsh_heading_table_name} (heading)")
  conn.query("CREATE INDEX lcsh_variant ON #{lcsh_variant_table_name} (heading)")
end

def create_naf_tables(conn)
  use_db_name_command(conn)
  conn.query("DROP TABLE IF EXISTS #{naf_heading_table_name}")
  conn.query("DROP TABLE IF EXISTS #{naf_variant_table_name}")
  conn.query(heading_table_create_query(naf_heading_table_name))
  conn.query(heading_table_create_query(naf_variant_table_name))
  conn.query("CREATE INDEX naf_authorized ON #{naf_heading_table_name} (heading)")
  conn.query("CREATE INDEX naf_variant ON #{naf_variant_table_name} (heading)")
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
  conn.query("DROP TABLE IF EXISTS #{lcgft_heading_table_name}")
  conn.query("DROP TABLE IF EXISTS #{lcgft_variant_table_name}")
  conn.query("DROP TABLE IF EXISTS #{lcgft_heading_string_table_name}")
  conn.query(heading_table_create_query(lcgft_heading_table_name))
  conn.query(heading_table_create_query(lcgft_variant_table_name))
  conn.query(heading_string_table_create_query(lcgft_heading_string_table_name))
  conn.query("CREATE INDEX lcgft_authorized ON #{lcgft_heading_table_name} (heading)")
  conn.query("CREATE INDEX lcgft_variant ON #{lcgft_variant_table_name} (heading)")
  conn.query("CREATE INDEX lcgft_uri ON #{lcgft_heading_string_table_name} (heading_string)")
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
