require_relative './../lib/authority_control'

conn = mysql_conn(host_name: MYSQL_HOST, user: MYSQL_USER, pass: MYSQL_PASS, database: DB_NAME)
lcsh_filename = './../tmp/lcsh.both.xml'
lcnaf_filename = './../tmp/lcnaf.both.xml'
lcgft_filename = './../tmp/all_lcgft.mrc'
auth_dir = File.join(File.dirname(__FILE__), './../marc')

populate_db(conn: conn, lcsh_filename: lcsh_filename, lcnaf_filename: lcnaf_filename, lcgft_filename: lcgft_filename, auth_dir: auth_dir)
