def populate_db(conn:, lcsh_filename:, lcnaf_filename:, lcgft_filename:, auth_dir:)
  create_auth_database(conn)
  use_db_name_command(conn)
  populate_lc_database(filename: lcsh_filename,
                       conn: conn,
                       create: true)
  populate_lc_database(filename: lcnaf_filename,
                       conn: conn,
                       create: false)
  populate_lcgft_database(filename: lcgft_filename, conn: conn)
  auth_files = Dir.glob("#{auth_dir}/*.mrc").sort_by { |file| File.mtime(file) }
  populate_marc_database(conn: conn, filename: auth_files[0], create: true)
  auth_files[1..-1].each do |file|
   puts "Starting #{File.basename(file)}"
   populate_marc_database(conn: conn, filename: file)
   puts "Finished #{File.basename(file)}"
  end
  remove_duplicate_headings_from_db(conn)
end

def subdivision_collection
  'http://id.loc.gov/authorities/subjects/collection_Subdivisions'
end

def insert_value_into_heading_table(conn:, table_name:, values:)
  conn.query("INSERT INTO #{table_name}(heading, lccn) VALUES('#{conn.escape(values[:heading])}','#{conn.escape(values[:lccn])}')")
end

def insert_value_into_marc_table(conn:, values:)
  conn.query("INSERT INTO lccn_to_marc(lccn, tag, indicators, subfields) VALUES('#{conn.escape(values[:lccn])}','#{conn.escape(values[:tag])}','#{conn.escape(values[:indicators])}','#{conn.escape(values[:subfields])}')")
end

def insert_value_into_lccn_uri_table(conn:, values:)
  conn.query("INSERT INTO lccn_to_uri (lccn, uri) VALUES('#{conn.escape(values[:lccn])}','#{conn.escape(values[:uri])}')")
end

def insert_value_into_heading_string_table(conn:, table_name:, values:)
  conn.query("INSERT INTO #{table_name}(uri, heading_string) VALUES('#{conn.escape(values[:uri])}','#{conn.escape(values[:heading_string])}')")
end

### Populate tables for LCGFT from MARC records
def populate_lcgft_database(conn:, filename:)
  create_lcgft_tables(conn)
  reader = MARC::Reader.new(filename)
  reader.each do |record|
    lccn = record['001'].value.strip
    uri = "http://id.loc.gov/authorities/genreForms/#{lccn}"
    heading_string = record['155']['a']
    f682 = record.fields('682')
    deprecated = false
    f682.each do |field|
      deprecated = true if field['i'] && field['i'] =~ /deleted/
    end
    next if deprecated
    string_values = { uri: uri, heading_string: heading_string }
    insert_value_into_heading_string_table(conn: conn, table_name: lcgft_heading_string_table_name, values: string_values)
    label = normalize_heading_for_local_search(heading: heading_string)
    alt_terms = record.fields('455')
    alt_terms.each do |alt_term|
      text = alt_term['a']
      text = normalize_heading_for_local_search(heading: text)
      insert_value_into_heading_table(conn: conn, table_name: lcgft_variant_table_name, values: { heading: text, lccn: lccn })
    end
    auth_values = { heading: label, lccn: lccn }
    insert_value_into_heading_table(conn: conn, table_name: lcgft_heading_table_name, values: auth_values)
    lccn_uri_values = { lccn: lccn, uri: uri }
    insert_value_into_lccn_uri_table(conn: conn, values: lccn_uri_values)
  end
end

def get_heading_from_marc(marc)
  f1xx = marc.fields('100'..'199').first
  values = {}
  values[:tag] = f1xx.tag
  values[:lccn] = lccn
  values[:indicators] = f1xx.indicator1 + f1xx.indicator2
  values[:subfields] = ''
  values[:subfields] << f1xx.subfields[0].code
  values[:subfields] << f1xx.subfields[0].value
  heading_string = ''
  f1xx.subfields[1..-1].each do |subfield|
    values[:subfields] << "|#{subfield.code}"
    values[:subfields] << subfield.value
    heading_string << subfield.value
  end
  values[:normalized_heading] = normalize_heading_for_local_search(heading_string)
  values
end

def subfields_for_variant_tag(tag)
  case tag
  when '400'
    %w[a b c d e f g h j k l m n o p q r s t v x y z]
  when '410'
    %w[a b c d e f g h k l m n o p r s t v x y z ]
  when '411'
    %w[a c d e f g h j k l n p q s r v x y z]
  when '430'
    %w[a d f g h k l m n o p r s t v x y z]
  when '450'
    %w[a b g v x y z]
  when '451'
    %w[a g v x y z]
  when '455'
    %w[a v x y z]
  end
end

def get_normalized_variants_from_marc(marc)
  variants = []
  f4xx = marc.fields('400'..'499')
  return variants if f4xx.empty?
  f4xx.each do |field|
    tag = field.tag
    wanted_subfields = subfields_for_variant_tag(tag)
    target_subfields = field.subfields.select { |subf| wanted_subfields.include?(subf.code) }
    string = target_subfields.map { |subf| subf.value }.join('')
    variants << normalize_heading_for_local_search(string)
  end
  variants
end

### Update LCSH or NAF tables with single records retrieved from id.loc.gov
def update_lc_database(conn:, lc_conn:, uri:)
  heading_table_name = NAF_HEADING_TABLE_NAME
  variant_table_name = NAF_VARIANT_TABLE_NAME
  if uri =~ /authorities\/subjects/
    heading_table_name = LCSH_HEADING_TABLE_NAME
    variant_table_name = LCSH_VARIANT_TABLE_NAME
  end
  uri_stub = uri.gsub(/^http:\/\/id.loc.gov(.*)$/, '1.marcxml.xml')
  response = lc_conn.get(uri_stub)
  status = response.status
  return status unless status == 200
  lccn = uri.gsub(/^.*\/authorities\/[a-zA-Z]+\/(.*)$/, '\1')
  lccn.strip!
  delete_row_by_lccn(conn: conn, table_name: heading_table_name, lccn: lccn)
  delete_row_by_lccn(conn: conn, table_name: variant_table_name, lccn: lccn)
  delete_row_by_lccn(conn: conn, table_name: 'lccn_to_uri', lccn: lccn)
  delete_row_by_lccn(conn: conn, table_name: 'lccn_to_marc', lccn: lccn)
  insert_value_into_lccn_uri_table(conn: conn, values: { lccn: lccn, uri: uri })

  reader = MARC::XMLReader.new(StringIO.new(response.body))
  record = reader.first
  heading = get_heading_from_marc(record)
  insert_value_into_marc_table(conn: conn, values: heading)
  insert_value_into_heading_table(conn: conn,
                                  table_name: heading_table_name,
                                  values: { heading: heading[:normalized_heading],
                                            lccn: lccn })
  variants = get_normalized_variants_from_marc(record)
  variants.each do |string|
    insert_value_into_heading_table(conn: conn,
                                    table_name: variant_table_name,
                                    values: { heading: string,
                                              lccn: lccn })
  end
  status
end

### Populate tables for LCSH
def populate_lc_database(conn:, filename:, create: false)
  if create
    create_lcsh_tables(conn)
    create_naf_tables(conn)
    create_lccn_uri_table(conn)
  else
    use_db_name_command(conn)
  end
  heading_table_name = nil
  variant_table_name = nil
  input = File.open(filename, 'r')
  count = 0
  while line = input.gets
    puts count if count % 10_000 == 0
    line.chomp!
    doc = Nokogiri::XML(line)
    doc.root.add_namespace('identifiers', 'http://id.loc.gov/vocabulary/identifiers/')
    description = doc.xpath('//rdf:Description[identifiers:lccn]').first
    description ||= doc.xpath('//rdf:Description[skos:prefLabel]').first
    next unless description
    deletion_note = doc.xpath('//madsrdf:deletionNote').first
    record_status = doc.xpath('//ri:recordStatus').first
    record_status = record_status.text if record_status
    next if record_status == 'deprecated'
    next if deletion_note
    members = description.xpath('madsrdf:isMemberOfMADSCollection').map { |element| element.attributes['resource'].value }
    next if members.include?(subdivision_collection)
    label = description.xpath('skos:prefLabel').first
    next unless label
    label = label.text
    label = normalize_heading_for_local_search(heading: label)
    about = description.attributes['about']
    next unless about
    uri = about.value
    next unless uri =~ /^http:\/\/id\.loc\.gov\/authorities\//
    lccn = uri.gsub(/^http:\/\/id\.loc\.gov\/authorities\/[a-z]+\/(.*)$/, '\1')
    next unless lccn =~ /^[a-z]+[0-9]+$/
    lccn_uri_values = { lccn: lccn, uri: uri }
    insert_value_into_lccn_uri_table(conn: conn, values: lccn_uri_values)
    case uri
    when /authorities\/subjects/
      heading_table_name = LCSH_HEADING_TABLE_NAME
      variant_table_name = LCSH_VARIANT_TABLE_NAME
    else
      heading_table_name = NAF_HEADING_TABLE_NAME
      variant_table_name = NAF_VARIANT_TABLE_NAME
    end
    alt_labels = description.xpath('skos:altLabel')
    alt_labels.each do |alt_label|
      text = alt_label.text
      text = normalize_heading_for_local_search(heading: text)
      insert_value_into_heading_table(conn: conn,
                                      table_name: variant_table_name,
                                      values: { heading: text, lccn: lccn })
    end
    auth_values = { heading: label, lccn: lccn }
    insert_value_into_heading_table(conn: conn,
                                    table_name: heading_table_name,
                                    values: auth_values)
    count += 1
  end
end

def populate_marc_database(conn:, filename:, create: false)
  if create
    create_lccn_marc_table(conn)
  else
    use_db_name_command(conn)
  end
  reader = MARC::Reader.new(filename)
  reader.each do |record|
    lccn = record['001'].value.strip
    next unless lccn =~ /^[a-z]+[0-9]+$/
    values = get_heading_from_marc(record)
    insert_value_into_marc_table(conn: conn, values: values)
  end
end

def duplicate_entries_query(table_name)
  %(
    SELECT heading, lccn
    FROM #{table_name}
    GROUP BY heading, lccn
    HAVING COUNT(heading_id) > 1
  )
end

def get_duplicate_entries(conn, table_name)
  entries = []
  results = conn.query(duplicate_entries_query(table_name))
  results.each do |row|
    entries << { heading: row['heading'], lccn: row['lccn'] }
  end
  entries
end

def duplicate_entries_headingids_query(table_name)
  %(
    SELECT heading_id
    FROM #{table_name}
    WHERE
      lccn = ?
      AND heading = ?
  )
end

def remove_duplicate_entries_headingids(conn:, table_name:, values:)
  ids = []
  query = conn.prepare(duplicate_entries_headingids_query(table_name))
  results = query.execute(values[:lccn], values[:heading])
  results.each { |row| ids << row['heading_id'] }
  ids.sort!
  query = conn.prepare(delete_heading_by_headingid_query(table_name))
  ids[1..-1].each do |id|
    query.execute(id)
  end
end

def delete_heading_by_headingid_query(table_name)
  %(
    DELETE FROM #{table_name}
    WHERE heading_id = ?
  )
end

def delete_heading_by_string_query(table_name)
  %(
    DELETE FROM #{table_name}
    WHERE heading = ?
  )
end

def delete_row_by_lccn_query(table_name)
  %(
    DELETE FROM #{table_name}
    WHERE lccn = ?
  )
end

def delete_row_by_lccn(conn:, table_name:, lccn:)
  query = conn.prepare(delete_heading_by_lccn_query(table_name))
  query.execute(lccn)
  query.close
end

def delete_duplicate_entries_headingids(conn, table_name)
  entries = get_duplicate_entries(conn, table_name)
  entries.each do |entry|
    remove_duplicate_entries_headingids(conn: conn,
                                        table_name: table_name,
                                        values: entry)
  end
end

def multiple_lccns_heading_query(table_name)
  %(
    SELECT heading
    FROM #{table_name}
    GROUP BY heading
    HAVING COUNT(lccn) > 1
  )
end

def lcsh_authorized_variant_heading_query
  %(
    SELECT lcsh_headings.heading
    FROM lcsh_headings
      JOIN lcsh_variants
        ON lcsh_headings.heading = lcsh_variants.heading
    WHERE lcsh_headings.lccn != lcsh_variants.lccn
  )
end

def naf_authorized_variant_heading_query
  %(
    SELECT naf_headings.heading
    FROM naf_headings
      JOIN naf_variants
        ON naf_headings.heading = naf_variants.heading
    WHERE naf_headings.lccn != naf_variants.lccn
  )
end

def lcgft_authorized_variant_heading_query
  %(
    SELECT lcgft_headings.heading
    FROM lcgft_headings
      JOIN lcgft_variants
        ON lcgft_headings.heading = lcgft_variants.heading
    WHERE lcgft_headings.lccn != lcgft_variants.lccn
  )
end

def remove_lcsh_authorized_variant_headings(conn)
  authorized_variants = []
  authorized_variant_results = conn.query(lcsh_authorized_variant_heading_query)
  authorized_variant_results.each { |row| authorized_variants << row['heading'] }
  authorized_variants.uniq!
  query = conn.prepare(delete_heading_string_query(LCSH_HEADING_TABLE_NAME))
  authorized_variants.each do |heading|
    query.execute(heading)
  end
  query = conn.prepare(delete_heading_string_query(LCSH_VARIANT_TABLE_NAME))
  authorized_variants.each do |heading|
    query.execute(heading)
  end
end

def remove_naf_authorized_variant_headings(conn)
  authorized_variants = []
  authorized_variant_results = conn.query(naf_authorized_variant_heading_query)
  authorized_variant_results.each { |row| authorized_variants << row['heading'] }
  authorized_variants.uniq!
  query = conn.prepare(delete_heading_string_query(NAF_HEADING_TABLE_NAME))
  authorized_variants.each do |heading|
    query.execute(heading)
  end
  query = conn.prepare(delete_heading_string_query(NAF_VARIANT_TABLE_NAME))
  authorized_variants.each do |heading|
    query.execute(heading)
  end
end

def remove_lcgft_authorized_variant_headings(conn)
  authorized_variants = []
  authorized_variant_results = conn.query(lcgft_authorized_variant_heading_query)
  authorized_variant_results.each { |row| authorized_variants << row['heading'] }
  authorized_variants.uniq!
  query = conn.prepare(delete_heading_string_query(LCGFT_HEADING_TABLE_NAME))
  authorized_variants.each do |heading|
    query.execute(heading)
  end
  query = conn.prepare(delete_heading_string_query(LCGFT_VARIANT_TABLE_NAME))
  authorized_variants.each do |heading|
    query.execute(heading)
  end
end

def remove_duplicate_lcsh(conn)
  delete_duplicate_entries_headingids(conn, lcsh_heading_table_name)
  delete_duplicate_entries_headingids(conn, lcsh_variant_table_name)
  remove_lcsh_authorized_variant_headings(conn)
  multiple_authorized = []
  multiple_authorized_results = conn.query(multiple_lccns_heading_query(lcsh_heading_table_name))
  multiple_authorized_results.each { |row| multiple_authorized << row['heading'] }
  multiple_authorized.uniq!
  query = conn.prepare(delete_heading_string_query(LCSH_HEADING_TABLE_NAME))
  multiple_authorized.each do |heading|
    query.execute(heading)
  end
  multiple_variant = []
  multiple_variant_results = conn.query(multiple_lccns_heading_query(lcsh_variant_table_name))
  multiple_variant_results.each { |row| multiple_variant << row['heading'] }
  multiple_variant.uniq!
  query = conn.prepare(delete_heading_string_query(LCSH_VARIANT_TABLE_NAME))
  multiple_variant.each do |heading|
    query.execute(heading)
  end
end

def remove_duplicate_naf(conn)
  delete_duplicate_entries_headingids(conn, naf_heading_table_name)
  delete_duplicate_entries_headingids(conn, naf_variant_table_name)
  remove_naf_authorized_variant_headings(conn)
  multiple_authorized = []
  multiple_authorized_results = conn.query(multiple_lccns_heading_query(naf_heading_table_name))
  multiple_authorized_results.each { |row| multiple_authorized << row['heading'] }
  multiple_authorized.uniq!
  query = conn.prepare(delete_heading_string_query(NAF_HEADING_TABLE_NAME))
  multiple_authorized.each do |heading|
    query.execute(heading)
  end
  multiple_variant = []
  multiple_variant_results = conn.query(multiple_lccns_heading_query(naf_variant_table_name))
  multiple_variant_results.each { |row| multiple_variant << row['heading'] }
  multiple_variant.uniq!
  query = conn.prepare(delete_heading_string_query(NAF_VARIANT_TABLE_NAME))
  multiple_variant.each do |heading|
    query.execute(heading)
  end
end

def remove_duplicate_lcgft(conn)
  delete_duplicate_entries_headingids(conn, lcgft_heading_table_name)
  delete_duplicate_entries_headingids(conn, lcgft_variant_table_name)
  remove_lcgft_authorized_variant_headings(conn)
  multiple_authorized = []
  multiple_authorized_results = conn.query(multiple_lccns_heading_query(lcgft_heading_table_name))
  multiple_authorized_results.each { |row| multiple_authorized << row['heading'] }
  multiple_authorized.uniq!
  query = conn.prepare(delete_heading_string_query(LCGFT_HEADING_TABLE_NAME))
  multiple_authorized.each do |heading|
    query.execute(heading)
  end
  multiple_variant = []
  multiple_variant_results = conn.query(multiple_lccns_heading_query(lcgft_variant_table_name))
  multiple_variant_results.each { |row| multiple_variant << row['heading'] }
  multiple_variant.uniq!
  query = conn.prepare(delete_heading_string_query(LCGFT_VARIANT_TABLE_NAME))
  multiple_variant.each do |heading|
    query.execute(heading)
  end
end

def remove_duplicate_headings_from_db(conn)
  remove_duplicate_lcsh(conn)
  remove_duplicate_naf(conn)
  remove_duplicate_lcgft(conn)
end
