MYSQL_HOST = ENV['AUTH_MYSQL_HOST'].freeze
MYSQL_USER = ENV['AUTH_MYSQL_USER'].freeze
MYSQL_PASS = ENV['AUTH_MYSQL_PASS'].freeze
DB_NAME = 'authorized_headings'.freeze
### Table names
LCSH_HEADING_TABLE_NAME = 'lcsh_headings'.freeze
LCSH_VARIANT_TABLE_NAME = 'lcsh_variants'.freeze

NAF_HEADING_TABLE_NAME = 'naf_headings'.freeze
NAF_VARIANT_TABLE_NAME = 'naf_variants'.freeze

LCGFT_HEADING_TABLE_NAME = 'lcgft_headings'.freeze
LCGFT_VARIANT_TABLE_NAME = 'lcgft_variants'.freeze
LCGFT_HEADING_STRING_TABLE_NAME = 'lcgft_heading_strings'.freeze
