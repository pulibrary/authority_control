def authorize_record(record:, conn:, remove_uris: false)
  if remove_uris
    record.fields.each do |field|
      next unless heading_fields.include?(field.tag)
      next if field.tag[0] == '6' && field.indicator2 != '0'
      field.subfields.delete_if { |subfield| subfield.code == '0' }
    end
  end
  format = record.leader[6]
  changed_rec = false
  bad_rec = false
  result = add_nametitle_uri(record: record, conn: conn)
  rec = result[:record]
  changed_rec = result[:changed_rec]
  bad_rec = result[:bad_rec]
  result = add_subject_uri(record: rec, conn: conn)
  rec = result[:record]
  changed_rec = true if result[:changed_rec]
  bad_rec = true if result[:bad_rec]
  result = add_lcgft_uri(record: rec, conn: conn)
  rec = result[:record]
  changed_rec = true if result[:changed_rec]
  bad_rec = true if result[:bad_rec]
  result = format == 'c' ? mus_lcgft_from_subject(record: rec, conn: conn) : lcgft_from_lcsh(record: rec, conn: conn)
  rec = result[:record]
  changed_rec = true if result[:changed_rec]
  result = lcgft_from_008(record: rec, conn: conn)
  rec = result[:record]
  changed_rec = true if result[:changed_rec]
  { record: rec, bad_rec: bad_rec, changed_rec: changed_rec }
end

### Fields eligible for authority control
def heading_fields
  %w[100 110 111 130 600 610 611 630 650 651 700 710 711 730]
end

### Retrieve a string from a subject field with the formatting required from id.loc.gov lookup
def get_subject_heading_from_field(field, heading_subfields)
  heading_string = ''
  field.subfields.each do |subfield|
    next unless heading_subfields.include? subfield.code
    next if subfield.value.nil?
    if %w[v x y z].include?(subfield.code)
      heading_string += '--'
    elsif field.subfields.index(subfield) > 0
      heading_string += ' '
    end
    heading_string += subfield.value
  end
  heading_string.strip
end

### Retrieve a string from a name/title field in the format
def get_heading_from_field(field, heading_subfields)
  heading_string = ''
  field.subfields.each do |subfield|
    next unless heading_subfields.include?(subfield.code)
    next if subfield.value.nil?
    heading_string += ' ' if field.subfields.index(subfield) > 0
    heading_string += subfield.value
  end
  heading_string.strip
end

def name_subfields_for_tag(tag)
  case tag
  when '600'
    %w[a b c d j q u f h k l m n o p r s t]
  when '610'
    %w[a b c d n u f h k l m o p r s t]
  when '611'
    %w[a c d e n q u f h k l p s t]
  when '630'
    %w[a d f h k l m n o p r s t]
  when '651'
    %w[a]
  when /^[17]00$/
    %w[a b c d j q u f h k l m n o p r s t v x]
  when /^[17]10$/
    %w[a b c d n u f h k l m o p r s t x]
  when /^[17]11$/
    %w[a c d e n q u f h k l p s t x]
  when /^[17]30$/
    %w[a d f h k l m n o p r s t x]
  end
end

def subject_subfields_for_tag(tag)
  case tag
  when '600'
    %w[a b c d j q u f h k l m n o p r s t g v x y z]
  when '610'
    %w[a b c u f h k l m o p r s t d g n v x y z]
  when '611'
    %w[a c e q u f h k l p s t d g n v x y z]
  when '630'
    %w[a d f g h k l m n o p r s t v x y z]
  when '650'
    %w[a b c d e g v x y z]
  when '651'
    %w[a g v x y z]
  when /^[17]00$/
    %w[a b c d j q u f h k l m n o p r s t x g]
  when /^[17]10$/
    %w[a b c u f h k l m o p r s t x d g n]
  when /^[17]11$/
    %w[a c e q u f h k l p s t x d g n]
  when /^[17]30$/
    %w[a d f g h k l m n o p r s t x]
  end
end

def heading_final_punct_regex
  /["\).\!\?\-]/
end

def normalize_heading_for_local_search(heading:, normal_form: :nfd)
  val = heading.dup
  val.scrub!('')
  val.unicode_normalize!(normal_form)
  val.gsub!(/[\u0300-\u036f\[\]]/, '')
  val.downcase!
  val.gsub!(/[[:punct:][:space:]]/, '')
  val[0..1023]
end

### Duplicate a MARC record so the original record is preserved
def duplicate_record(record)
  raw_marc = ''
  writer = MARC::Writer.new(StringIO.new(raw_marc, 'w'))
  writer.write(record)
  writer.close
  reader = MARC::Reader.new(StringIO.new(raw_marc, 'r'),
                            external_encoding: 'UTF-8',
                            invalid: :replace,
                            replace: '')
  reader.first
end

### Look up term in MySQL database, add URI if valid
def add_lcgft_uri(record:, conn:)
  changed_rec = false
  bad_rec = false
  heading_subfields = %w[a]
  rec = duplicate_record(record)
  rec.fields('655').each do |field|
    next unless field['0'].nil?
    next unless field.indicator2 == '7' && field['2'] == 'lcgft'
    field_index = rec.fields.index(field)
    heading_string = get_heading_from_field(field, heading_subfields)
    search_string = normalize_heading_for_local_search(heading: heading_string)
    target_lccn = get_lccn_from_local_db(conn: conn,
                                       heading: search_string,
                                       query: authorized_lcgft_lccn_query)
    if target_lccn.nil?
      target_lccn = get_lccn_from_local_db(conn: conn,
                                         heading: search_string,
                                         query: variant_lcgft_lccn_query)
    end
    next unless target_lccn
    target_uri = "http://id.loc.gov/authorities/genreForms/#{target_lccn}"

    changed_rec = true
    authorized_form = get_pref_lcgft_from_local_db(conn: conn,
                                                   uri: target_uri,
                                                   query: lcgft_heading_string_query)
    next unless authorized_form
    unless authorized_form.gsub(/[[:punct:][:space:]]/, '') == field['a'].gsub(/[[:punct:][:space:]]/, '')
      bad_rec = true
    end
    new_field = MARC::DataField.new('655', ' ', '7')
    new_field.append(MARC::Subfield.new('a', authorized_form))
    unless new_field.subfields[-1].value =~ heading_final_punct_regex
      new_field.subfields[-1].value << '.'
    end
    new_field = add_non_heading_subfields_to_subject_field(field, new_field)
    new_field.append(MARC::Subfield.new('2', 'lcgft'))
    new_field.append(MARC::Subfield.new('0', target_uri))
    rec.fields[field_index] = new_field
  end
  { record: rec, changed_rec: changed_rec, bad_rec: bad_rec }
end

def auth_field_from_marc_info(heading_info)
  field = MARC::DataField.new(heading_info[:tag],
                              heading_info[:indicator1],
                              heading_info[:indicator2])
  heading_info[:subfields].each do |subfield_string|
    code = subfield_string[0]
    value = subfield_string[1..-1]
    field.append(MARC::Subfield.new(code, value))
  end
  field
end

### Uses MySQL database to resolve a normalized name or name/title heading
###   to a URI;
### then it gets the authorized form
def add_nametitle_uri(record:, conn:)
  tags_of_interest = %w[100 700 110 710 111 711 130 730 600 610 611 630 651]
  changed_rec = false
  bad_rec = false
  rec = duplicate_record(record)
  rec.fields.each do |field|
    orig_tag = field.tag
    next unless tags_of_interest.include? orig_tag
    next unless field['0'].nil?
    field_index = rec.fields.index(field)
    field_map = field.subfields.map(&:code)
    next if orig_tag[0] == '6' &&
            (field.indicator2 != '0' || field_map.any? { |code| code =~ /[vxyz]/ })
    heading_subfields = name_subfields_for_tag(orig_tag)
    heading_string = get_heading_from_field(field, heading_subfields)
    search_string = normalize_heading_for_local_search(heading: heading_string)
    target_lccn = get_lccn_from_local_db(conn: conn,
                                         heading: search_string,
                                         query: authorized_naf_lccn_query)
    if target_lccn.nil?
      target_lccn = get_lccn_from_local_db(conn: conn,
                                           heading: search_string,
                                           query: variant_naf_lccn_query)
    end
    next unless target_lccn
    heading_info = get_marc_and_uri_from_lccn(conn: conn,
                                              lccn: target_lccn)
    next unless heading_info
    changed_rec = true
    target_uri = heading_info[:uri]
    auth_field = auth_field_from_marc_info(heading_info)
    auth_indicator1 = auth_field.indicator1
    auth_indicator2 = auth_field.indicator2
    auth_tag_portion = auth_field.tag[1..2]
    auth_tag_portion = '10' if orig_tag =~ /^[17]/ && auth_tag_portion == '51'
    new_tag = orig_tag[0] + auth_tag_portion
    orig_field = ''
    field.subfields.each do |subfield|
      next unless heading_subfields.include?(subfield.code)
#      orig_field << subfield.code  Ignore code errors for now
      orig_field << subfield.value
    end
    orig_field.gsub!(/[[:punct:][:space:]]/, '')
    orig_field.unicode_normalize!(:nfd)
    auth_field_string = ''
    auth_field.subfields.each do |subfield|
#      auth_field_string << subfield.code  Ignore code errors for now
      auth_field_string << subfield.value
    end
    auth_field_string.gsub!(/[[:punct:][:space:]]/, '')
    auth_field_string.unicode_normalize!(:nfd)
    bad_rec = true unless orig_field == auth_field_string
### Not a priority to identify incorrect indicators
#    bad_rec = true if auth_field.tag == '151' &&
#                      orig_tag == '651' &&
#                      field.indicator1 != ' '
#    bad_rec = true if auth_field.tag != '151' &&
#                      auth_tag_portion != orig_tag[1..2] &&
#                      auth_indicator1 != field.indicator1
#    bad_rec = true if auth_field.tag == '130' &&
#                      %w[130 730].include?(orig_tag) &&
#                      auth_indicator2 != field.indicator1
    new_field = nil
    case orig_tag
    when /^.[01]|^651$/
      new_field = MARC::DataField.new(new_tag, auth_indicator1, field.indicator2)
    when /^.3/
      new_field = MARC::DataField.new(new_tag, auth_indicator2, field.indicator2)
    end
    auth_subfields = auth_field.subfields
    auth_subfields.each do |auth_subfield|
      new_field.append(auth_subfield)
    end
    case orig_tag
    when /^[167][013]0$|^651$/
      subfe = field.subfields.select { |subfield| subfield.code == 'e' }
      unless subfe.empty?
        new_field.subfields[-1].value = new_field.subfields[-1].value + ',' unless new_field.subfields[-1].value[-1] == '-'
        subfe.each do |subfield|
          new_field.append(subfield)
        end
      end
    when /^[167]11$/
      subfj = field.subfields.select { |subfield| subfield.code == 'j' }
      unless subfj.empty?
        new_field.subfields[-1].value = new_field.subfields[-1].value + ',' unless new_field.subfields[-1].value[-1] == '-'
        subfj.each do |subfield|
          new_field.append(subfield)
        end
      end
    end
    new_field.subfields[-1].value += '.' unless new_field.subfields[-1].value[-1] =~ /.*["\).\!\?\-]$/
    new_field = add_non_heading_subfields_to_name_field(field, new_field)
    new_field.subfields.delete_if { |subfield| subfield.code == '0' }
    new_field.append(MARC::Subfield.new('0', target_uri))
    rec.fields[field_index] = new_field
  end
  { record: rec,
    changed_rec: changed_rec,
    bad_rec: bad_rec }
end

### Uses MySQL database to resolve a normalized LCSH to a URI;
###   then it gets the authorized form
def add_subject_uri(record:, conn:)
  tags_of_interest = %w[600 610 611 630 650 651]
  changed_rec = false
  bad_rec = false
  rec = duplicate_record(record)
  fields_of_interest = rec.fields.select do |field|
    tags_of_interest.include?(field.tag) && field.indicator2 == '0'
  end
  fields_of_interest.each do |field|
    next unless field['0'].nil?
    orig_tag = field.tag
    field_index = rec.fields.index(field)
    field_map = field.subfields.map(&:code)
    ### Ignore name subject headings that don't have subject subdivisions
    next if orig_tag != '650' && (field_map & %w[v x y z]).nil?
    heading_subfields = subject_subfields_for_tag(orig_tag)
    heading_string = get_subject_heading_from_field(field, heading_subfields)
    search_string = normalize_heading_for_local_search(heading: heading_string)
    target_lccn = get_lccn_from_local_db(conn: conn,
                                         heading: search_string,
                                         query: authorized_lcsh_lccn_query)
    if target_lccn.nil?
      target_lccn = get_lccn_from_local_db(conn: conn,
                                           heading: search_string,
                                           query: variant_lcsh_lccn_query)
    end
    next unless target_lccn
    heading_info = get_marc_and_uri_from_lccn(conn: conn,
                                              lccn: target_lccn)
    next unless heading_info
    target_uri = heading_info[:uri]
    auth_field = auth_field_from_marc_info(heading_info)
    next unless auth_field
    next if auth_field.tag[1] == '8'
    changed_rec = true
    auth_indicator1 = auth_field.indicator1
    auth_indicator2 = auth_field.indicator2
    auth_tag_portion = auth_field.tag[1..2]
    new_tag = orig_tag[0] + auth_tag_portion
    orig_field = ''
    field.subfields.each do |subfield|
      next unless heading_subfields.include?(subfield.code)
#      orig_field << subfield.code  Ignore code errors for now
      orig_field << subfield.value
    end
    orig_field.gsub!(/[[:punct:][:space:]]/, '')
    orig_field.unicode_normalize!(:nfd)
    auth_field_string = ''
    auth_field.subfields.each do |subfield|
#      auth_field_string << subfield.code  Ignore code errors for now
      auth_field_string << subfield.value
    end
    auth_field_string.gsub!(/[[:punct:][:space:]]/, '')
    auth_field_string.unicode_normalize!(:nfd)
    bad_rec = true unless (orig_field == auth_field_string) && orig_tag == new_tag
    ### Not a priority to identify incorrect indicators
#    bad_rec = true if auth_field.tag == '130' && auth_indicator2 != field.indicator1
#    bad_rec = true if auth_field.tag != '130' && auth_indicator1 != field.indicator1
    new_field = case orig_tag
                when /^6[015]/
                  MARC::DataField.new(new_tag,
                                      auth_indicator1,
                                      field.indicator2)
                when /^63/
                  MARC::DataField.new(new_tag,
                                      auth_indicator2,
                                      field.indicator2)
                end
    auth_subfields = auth_field.subfields
    auth_subfields.each do |auth_subfield|
      new_field.append(auth_subfield)
    end
    case orig_tag
    when /^6[013]0$|^651$/
      subfe = field.subfields.select { |subfield| subfield.code == 'e' }
      unless subfe.empty?
        new_field.subfields[-1].value += ',' unless new_field.subfields[-1].value[-1] == '-'
        subfe.each do |subfield|
          new_field.append(subfield)
        end
      end
    when /^611$/
      subfj = field.subfields.select { |subfield| subfield.code == 'j' }
      unless subfj.empty?
        new_field.subfields[-1].value += ',' unless new_field.subfields[-1].value[-1] == '-'
        subfj.each do |subfield|
          new_field.append(subfield)
        end
      end
    end
    new_field.subfields[-1].value = new_field.subfields[-1].value + '.' unless new_field.subfields[-1].value[-1] =~ /.*["\).\!\?\-]$/
    new_field = add_non_heading_subfields_to_subject_field(field, new_field)
    new_field.append(MARC::Subfield.new('0', target_uri))
    rec.fields[field_index] = new_field
  end
  { record: rec,
    changed_rec: changed_rec,
    bad_rec: bad_rec }
end

### Adds subfields 3, 4, 5, 6, and 8 to a corrected heading or a derived heading
###   in the LCSH vocabulary
def add_non_heading_subfields_to_subject_field(field, new_field)
  subf4 = field.subfields.select { |subfield| subfield.code == '4' }
  subf4.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  subf5 = field.subfields.select { |subfield| subfield.code == '5' }
  subf5.each do |subfield|
    new_field.subfields.append(subfield)
  end
  subf3 = field.subfields.select { |subfield| subfield.code == '3' }
  subf3.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  subf6 = field.subfields.select { |subfield| subfield.code == '6' }
  subf6.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  subf8 = field.subfields.select { |subfield| subfield.code == '8' }
  subf8.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  new_field
end

### Adds subfields 3, 4, 5, 6, 8, and i to a corrected heading
###   or a derived heading in NAF
def add_non_heading_subfields_to_name_field(field, new_field)
  subf4 = field.subfields.select { |subfield| subfield.code == '4' }
  subf4.each do |subfield|
    new_field.append(subfield)
  end
  subf5 = field.subfields.select { |subfield| subfield.code == '5' }
  subf5.each do |subfield|
    new_field.subfields.append(subfield)
  end
  subfi = field.subfields.select { |subfield| subfield.code == 'i' }
  subfi.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  subf3 = field.subfields.select { |subfield| subfield.code == '3' }
  subf3.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  subf6 = field.subfields.select { |subfield| subfield.code == '6' }
  subf6.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  subf8 = field.subfields.select { |subfield| subfield.code == '8' }
  subf8.each do |subfield|
    new_field.subfields.insert(0, subfield)
  end
  new_field
end
