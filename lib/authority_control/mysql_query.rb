def all_uris
  %(
    SELECT uri
    FROM lccn_to_uri
  )
end

def delete_by_lccn_query(table_name)
  %(
    DELETE FROM #{table_name}
    WHERE lccn = ?
  )
end

def lccn_from_heading_query(table_name)
  %(
    SELECT lccn
    FROM #{table_name}
    WHERE heading = ?
  )
end

def authorized_naf_lccn_query
  %(
    SELECT lccn
    FROM naf_headings
    WHERE heading = ?
  )
end

def variant_naf_lccn_query
  %(
    SELECT lccn
    FROM naf_variants
    WHERE heading = ?
  )
end

def authorized_lcsh_lccn_query
  %(
    SELECT lccn
    FROM lcsh_headings
    WHERE heading = ?
  )
end

def variant_lcsh_lccn_query
  %(
    SELECT lccn
    FROM lcsh_variants
    WHERE heading = ?
  )
end

def authorized_lcgft_lccn_query
  %(
    SELECT lccn
    FROM lcgft_headings
    WHERE heading = ?
  )
end

def variant_lcgft_lccn_query
  %(
    SELECT lccn
    FROM lcgft_variants
    WHERE heading = ?
  )
end

def lcgft_heading_string_query
  %(
    SELECT heading_string
    FROM lcgft_heading_strings
    WHERE uri = ?
  )
end

def marc_and_uri_from_lccn
  %(
    SELECT
      lccn_to_marc.lccn,
      lccn_to_marc.tag,
      lccn_to_marc.indicators,
      lccn_to_marc.subfields,
      lccn_to_uri.uri
    FROM lccn_to_marc
      JOIN lccn_to_uri
        ON lccn_to_marc.lccn = lccn_to_uri.lccn
    WHERE lccn_to_marc.lccn = ?
  )
end

def get_all_uris(conn)
  uris = []
  conn.query(all_uris).each do |row|
    uris << row['uri']
  end
  uris
end

def get_marc_and_uri_from_lccn(conn:, lccn:)
  statement = conn.prepare(marc_and_uri_from_lccn)
  result = statement.execute(lccn)
  values = result.first
  return values if values.nil?
  { lccn: values['lccn'],
    tag: values['tag'],
    indicator1: values['indicators'][0],
    indicator2: values['indicators'][1].to_s,
    subfields: values['subfields'].split('|'),
    uri: values['uri']
  }
end

def get_lccn_from_local_db(conn:, heading:, table_name:)
  heading = conn.escape(heading)
  statement = conn.prepare(lccn_from_heading_query(table_name))
  result = statement.execute(heading)
  lccn = result.first['lccn'] if result.first
  lccn ||= nil
  statement.close
  lccn
end

def get_pref_lcgft_from_local_db(conn:, uri:, query:)
  uri = conn.escape(uri)
  statement = conn.prepare(query)
  result = statement.execute(uri)
  result.first ? result.first['heading_string'] : result.first
end

def uri_for_lcgft
  %(
    SELECT uri
    FROM lcgft_heading_strings
    WHERE heading_string = ?
  )
end

def get_uri_for_lcgft(conn:, heading:)
  heading = conn.escape(heading)
  statement = conn.prepare(uri_for_lcgft)
  result = statement.execute(heading)
  result.first ? result.first['uri'] : result.first
end
