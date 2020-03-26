### Add LCGFTs to a record based on form subdivisions (subfield v) in LCSH
def lcgft_from_lcsh(record:, conn:)
  form_subfield_codes = %w[v]
  changed_rec = false
  rec = duplicate_record(record)
  relevant_fields = rec.fields('600'..'699')
  return { record: rec, changed_rec: changed_rec } if relevant_fields.empty?
  ### insert the LCGFTs after the last subject field
  last_subj_index = rec.fields.index(relevant_fields[-1])
  relevant_fields.each do |field|
    next unless field.indicator2 == '0'
    subf3 = field.subfields.select { |subfield| subfield.code == '3' }
    subf5 = field.subfields.select { |subfield| subfield.code == '5' }
    form_subfields = field.subfields.select do |subfield|
      form_subfield_codes.include?(subfield.code)
    end
    form_subfields.each do |subfield|
      heading_string = subfield.value
      next if heading_string =~ /^[Mmusic]$/
      heading = normalize_heading_for_local_search(heading: heading_string)
      target_lccn = get_lccn_from_local_db(conn: conn,
                                         heading: heading,
                                         query: authorized_lcgft_lccn_query)
      if target_lccn.nil?
        target_lccn = get_lccn_from_local_db(conn: conn,
                                           heading: heading,
                                           query: variant_lcgft_lccn_query)
      end
      next unless target_lccn
      target_uri = "http://id.loc.gov/authorities/genreForms/#{target_lccn}"
      pref_name = get_pref_lcgft_from_local_db(conn: conn,
                                               uri: target_uri,
                                               query: lcgft_heading_string_query)
      next unless pref_name
      pref_name += '.' unless pref_name[-1] =~ heading_final_punct_regex
      new_field = MARC::DataField.new('655', ' ', '7')
      new_field.append(MARC::Subfield.new('a', pref_name))
      new_field.append(MARC::Subfield.new('2', 'lcgft'))
      new_field.append(MARC::Subfield.new('0', target_uri))
      subf3.each do |subf|
        new_field.subfields.insert(0, subf)
      end
      subf5.each do |subf|
        new_field.subfields.append(subf)
      end
      changed_rec = true
      rec.fields.insert((last_subj_index + 1), new_field)
    end
  end
  f655 = rec.fields('655').reverse
  f655a = []
  f655.each do |field|
    next unless field['2'] == 'lcgft'
    index = rec.fields.index(field)
    if f655a.include?(field['a'])
      rec.fields.delete_at(index)
    else
      f655a << field['a']
    end
  end
  { record: rec, changed_rec: changed_rec }
end

def add_lcgft_from_terms(terms:, record:, conn:)
  terms.each do |term|
    uri = get_uri_for_lcgft(conn: conn, heading: term)
    next unless uri
    record = add_lcgft_to_record(uri: uri, term: term, record: record)
  end
  record
end

def add_lcgft_to_record(uri:, term:, record:)
  return record if uri.nil?
  field = MARC::DataField.new('655', ' ', '7')
  term += '.' unless term[-1] =~ heading_final_punct_regex
  field.append(MARC::Subfield.new('a', term))
  field.append(MARC::Subfield.new('2', 'lcgft'))
  field.append(MARC::Subfield.new('0', uri))
  record.append(field)
  record
end

def mus_006_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  f006 = record['006'].value
  composition_form = f006[1..2]
  term = mus_008_composition_form_to_lcgft_term[composition_form]
  return result_hash unless term
  record = add_lcgft_from_terms(terms: [term], record: record, conn: conn)
  result_hash[:changed_rec] = true
  result_hash[:record] = record
  result_hash
end

def mus_008_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  f008 = record['008'].value
  return result_hash unless f008
  composition_form = f008[18..19]
  term = mus_008_composition_form_to_lcgft_term[composition_form]
  return result_hash unless term
  record = add_lcgft_from_terms(terms: [term], record: record, conn: conn)
  result_hash[:changed_rec] = true
  result_hash[:record] = record
  result_hash
end

def book_006_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['006']
  f006 = record['006'].value
  form = f006[6]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  ### Disregard form of contents terms for now
#  contents = f006[7..10]
#  content_terms = book_cr_008_contents_to_lcgft_terms(contents)
#  unless content_terms.empty?
#    record = add_lcgft_from_terms(terms: content_terms, record: record, conn: conn)
#    result_hash[:changed_rec] = true
#  end
  lit_form = f006[16]
  lit_form_term = book_lit_form_to_lcgft_hash[lit_form]
  if lit_form_term
    record = add_lcgft_from_terms(terms: [lit_form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  result_hash[:record] = record
  result_hash
end

def book_008_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['008']
  f008 = record['008'].value
  return result_hash if f008.size != 40
  form = f008[23]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  ### Disregard form of contents terms for now
#  contents = f008[24..27]
#  content_terms = book_cr_008_contents_to_lcgft_terms(contents)
#  unless content_terms.empty?
#    record = add_lcgft_from_terms(terms: content_terms, record: record)
#    result_hash[:changed_rec] = true
#  end
  lit_form = f008[33]
  lit_form_term = book_lit_form_to_lcgft_hash[lit_form]
  if lit_form_term
    record = add_lcgft_from_terms(terms: [lit_form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  result_hash[:record] = record
  result_hash
end

def map_006_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['006']
  f006 = record['006'].value
  form = f006[12]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  formats = f006[16..17]
  format_terms = map_formats_to_lcgft_terms(formats)
  unless format_terms.empty?
    record = add_lcgft_from_terms(terms: format_terms, record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  result_hash[:record] = record
  result_hash
end

def map_008_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['008']
  f008 = record['008'].value
  return result_hash if f008.size != 40
  form = f008[23]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  formats = f008[33..34]
  format_terms = map_formats_to_lcgft_terms(formats)
  unless format_terms.empty?
    record = add_lcgft_from_terms(terms: format_terms, record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  result_hash[:record] = record
  result_hash
end

def cr_006_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['006']
  f006 = record['006'].value
  form = f006[6]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  ### Disregard form of contents terms for now
#  contents = f006[7..10]
#  content_terms = book_cr_008_contents_to_lcgft_terms(contents)
#  unless content_terms.empty?
#    record = add_lcgft_from_terms(terms: content_terms, record: record, conn: conn)
#    result_hash[:changed_rec] = true
#  end
  result_hash[:record] = record
  result_hash
end

def cr_008_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['008']
  f008 = record['008'].value
  return result_hash if f008.size != 40
  form = f008[23]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
### Disregard form of contents terms for now
#  contents = f008[24..27]
#  content_terms = book_cr_008_contents_to_lcgft_terms(contents)
#  unless content_terms.empty?
#    record = add_lcgft_from_terms(terms: content_terms, record: record, conn: conn)
#    result_hash[:changed_rec] = true
#  end
  result_hash[:record] = record
  result_hash
end

def visual_006_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['006']
  f006 = record['006'].value
  form = f006[12]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  visual_type = f006[16]
  visual_type_term = visual_type_to_lcgft_hash[visual_type]
  if visual_type_term
    record = add_lcgft_from_terms(terms: [visual_type_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  result_hash[:record] = record
  result_hash
end

def visual_008_lcgft(record:, conn:)
  changed_rec = false
  result_hash = { changed_rec: changed_rec, record: record }
  return result_hash unless record['008']
  f008 = record['008'].value
  return result_hash if f008.size != 40
  form = f008[23]
  form_term = form_008_to_lcgft_term[form]
  if form_term
    record = add_lcgft_from_terms(terms: [form_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  visual_type = f008[33]
  visual_type_term = visual_type_to_lcgft_hash[visual_type]
  if visual_type_term
    record = add_lcgft_from_terms(terms: [visual_type_term], record: record, conn: conn)
    result_hash[:changed_rec] = true
  end
  result_hash[:record] = record
  result_hash
end

def lcgft_from_006(record:, conn:)
  changed_rec = false
  rec = duplicate_record(record)
  result = { changed_rec: changed_rec, record: rec }
  return result unless record['006']
  case record['006'].value[0]
  when 'a', 't'
    result = book_006_lcgft(record: rec, conn: conn)
  when 'c', 'd', 'i', 'j'
    result = mus_006_lcgft(record: rec, conn: conn)
  when 'e', 'f'
    result = map_006_lcgft(record: rec, conn: conn)
  when 'g', 'k', 'o', 'r'
    result = visual_006_lcgft(record: rec, conn: conn)
  when 's'
    result = cr_006_lcgft(record: rec, conn: conn)
  end
  result
end

def lcgft_from_008(record:, conn:)
  changed_rec = false
  format = record.leader[6..7]
  rec = duplicate_record(record)
  if music.include?(format)
    result = mus_008_lcgft(record: rec, conn: conn)
    changed_rec = result[:changed_rec]
    rec = result[:record]
  elsif book.include?(format)
    result = book_008_lcgft(record: rec, conn: conn)
    changed_rec = result[:changed_rec]
    rec = result[:record]
  elsif map.include?(format)
    result = map_008_lcgft(record: rec, conn: conn)
    changed_rec = result[:changed_rec]
    rec = result[:record]
  elsif continuing_resource.include?(format)
    result = cr_008_lcgft(record: rec, conn: conn)
    changed_rec = result[:changed_rec]
    rec = result[:record]
  elsif visual.include?(format)
    result = visual_008_lcgft(record: rec, conn: conn)
    changed_rec = result[:changed_rec]
    rec = result[:record]
  end
  { record: rec, changed_rec: changed_rec }
end

def mus_lcgft_from_subject(record:, conn:)
  form_subfield_codes = %w[v x]
  changed_rec = false
  arranged = false
  format = record.leader[6..7]
  return { record: record, changed_rec: changed_rec } unless music.include?(format)
  rec = duplicate_record(record)
  relevant_fields = rec.fields('650')
  return { record: rec, changed_rec: changed_rec } if relevant_fields.empty?
  last650 = relevant_fields[-1]
  last650_index = rec.fields.index(last650)
  relevant_fields.each do |field|
    subf3 = field.subfields.select { |subfield| subfield.code == '3' }
    subf5 = field.subfields.select { |subfield| subfield.code == '5' }
    next unless field.indicator2 == '0'
    next unless field['a']
    subfa = field['a'].gsub(/^(.*)\.$/, '\1')
    arranged = true if subfa =~ /^.*, Arranged$/
    heading_string = subfa.gsub(/^(.*),.*$/, '\1').gsub(/^(.*) \(.*$/, '\1')
    uri = get_uri_for_lcgft(conn: conn, heading: heading_string)
    if uri && heading_string != 'Music'
      pref_name = heading_string
      pref_name << '.' unless pref_name[-1] =~ heading_final_punct_regex
      new_field = MARC::DataField.new('655', ' ', '7')
      new_field.append(MARC::Subfield.new('a', pref_name))
      new_field.append(MARC::Subfield.new('2', 'lcgft'))
      new_field.append(MARC::Subfield.new('0', uri))
      subf3.each do |subfield|
        new_field.subfields.insert(0, subfield)
      end
      subf5.each do |subfield|
        new_field.subfields.append(subfield)
      end
      rec.fields.insert((last650_index + 1), new_field)
      changed_rec = true
    else
      headings = music_form_translations[heading_string]
      if headings
        changed_rec = true
        headings.each_pair do |heading, target_uri|
          pref_name = ''
          pref_name << heading
          pref_name << '.' unless pref_name[-1] =~ heading_final_punct_regex
          new_field = MARC::DataField.new('655', ' ', '7')
          new_field.append(MARC::Subfield.new('a', pref_name))
          new_field.append(MARC::Subfield.new('2', 'lcgft'))
          new_field.append(MARC::Subfield.new('0', target_uri))
          subf3.each do |subfield|
            new_field.subfields.insert(0, subfield)
          end
          subf5.each do |subfield|
            new_field.subfields.append(subfield)
          end
          rec.fields.insert((last650_index + 1), new_field)
        end
      end
    end
    form_subfields = field.subfields.select do |subfield|
      form_subfield_codes.include?(subfield.code)
    end
    form_subfields.each do |subfield|
      value = subfield.value.gsub(/^(.*)\.$/, '\1')
      headings = music_form_translations[value]
      next unless headings
      changed_rec = true
      headings.each_pair do |heading, target_uri|
        pref_name = ''
        pref_name << heading
        pref_name << '.' unless pref_name[-1] =~ heading_final_punct_regex
        new_field = MARC::DataField.new('655', ' ', '7')
        new_field.append(MARC::Subfield.new('a', pref_name))
        new_field.append(MARC::Subfield.new('2', 'lcgft'))
        new_field.append(MARC::Subfield.new('0', target_uri))
        subf3.each do |subf|
          new_field.subfields.insert(0, subf)
        end
        subf5.each do |subf|
          new_field.subfields.append(subf)
        end
        rec.fields.insert((last650_index + 1), new_field)
      end
    end
  end
  if arranged
    rec.fields.insert((last650_index + 1), arranged_genre_field)
    changed_rec = true
  end
  f655 = rec.fields('655').reverse
  f655a = []
  f655.each do |field|
    index = rec.fields.index(field)
    if f655a.include?(field['a'])
      rec.fields.delete_at(index)
    else
      f655a << field['a']
    end
  end
  { record: rec, changed_rec: changed_rec }
end
