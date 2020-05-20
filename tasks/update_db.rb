require_relative './../lib/authority_control'
require 'json'

conn = lc_conn

lcgft_last_dump = Time.new(2019, 9, 26)
naf_last_dump = Time.new(2020, 1, 9)
lcsh_last_dump = Time.new(2020, 4, 1)

update_uris = []
### LCGFT update
1.upto(5001) do |page_num|
  response = conn.get "/authorities/genreForms/feed/#{page_num}"
  doc = Nokogiri::XML(response.body)
  last_entry = doc.xpath('//xmlns:entry').last
  last_entry_time = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_entry_time).to_time
  do_next = last_entry_time > lcgft_last_dump
  links = doc.xpath('//xmlns:entry/xmlns:link').select { |element| element['type'].nil? }
  ids = links.map { |element| element['href'].gsub(/^http:\/\/id.loc.gov(.*)$/, '\1') }
  ids.each do |uri|
    update_uris << uri
  end
  break unless do_next
end

### NAF update
292.upto(5001) do |page_num|
  response = conn.get "/authorities/names/feed/#{page_num}"
  doc = Nokogiri::XML(response.body)
  last_entry = doc.xpath('//xmlns:entry').last
  last_entry_time = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_entry_time).to_time
  do_next = last_entry_time > naf_last_dump
  links = doc.xpath('//xmlns:entry/xmlns:link').select { |element| element['type'].nil? }
  ids = links.map { |element| element['href'].gsub(/^http:\/\/id.loc.gov(.*)$/, '\1') }
  ids.each do |uri|
    update_uris << uri
  end
  break unless do_next
end

### LCSH update
1.upto(5001) do |page_num|
  response = conn.get "/authorities/subjects/feed/#{page_num}"
  doc = Nokogiri::XML(response.body)
  last_entry = doc.xpath('//xmlns:entry').last
  last_entry_time = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_entry_time).to_time
  do_next = last_entry_time > lcsh_last_dump
  links = doc.xpath('//xmlns:entry/xmlns:link').select { |element| element['type'].nil? }
  ids = links.map { |element| element['href'].gsub(/^http:\/\/id.loc.gov(.*)$/, '\1') }
  ids.each do |uri|
    update_uris << uri
  end
  break unless do_next
end

### LCGFT deletes
delete_uris = []
0.upto(2000) do |page_num|
  offset = ((page_num * 20) + 1).to_s
  response = conn.get do |req|
    req.url('search/')
    req.options.params_encoder = Faraday::FlatParamsEncoder
    req.params = {
                   q: [
                        'rdftype:DeprecatedAuthority',
                        'sort:mdate-descending',
                        'rdftype:GenreForm'
                      ],
                   format: 'atom',
                   start: offset }
  end
  doc = Nokogiri::XML(response.body)
  entries = doc.xpath('//xmlns:entry')
  last_entry = entries[-1]
  last_mod = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_mod).to_time
  do_next = last_entry_time > lcgft_last_dump
  entries.each do |entry|
    links = entry.xpath("xmlns:link[@rel='alternate']")
    uri_entry = links.select { |link| link['href'] =~ /^.*\/[0-9a-z]+$/ }.first
    next unless uri_entry
    uri = uri_entry['href']
    delete_uris << uri
  end
  break unless do_next
end

### NAF deletes
0.upto(2000) do |page_num|
  offset = ((page_num * 20) + 1).to_s
  response = conn.get do |req|
    req.url('search/')
    req.options.params_encoder = Faraday::FlatParamsEncoder
    req.params = {
                   q: [
                        'rdftype:DeprecatedAuthority',
                        'sort:mdate-descending',
                        'rdftype:Name'
                      ],
                   format: 'atom',
                   start: offset }
  end
  doc = Nokogiri::XML(response.body)
  entries = doc.xpath('//xmlns:entry')
  last_entry = entries[-1]
  last_mod = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_mod).to_time
  do_next = last_entry_time > naf_last_dump
  entries.each do |entry|
    links = entry.xpath("xmlns:link[@rel='alternate']")
    uri_entry = links.select { |link| link['href'] =~ /^.*\/[0-9a-z]+$/ }.first
    next unless uri_entry
    uri = uri_entry['href']
    delete_uris << uri
  end
  break unless do_next
end

### NAF Name-Title deletes
0.upto(2000) do |page_num|
  offset = ((page_num * 20) + 1).to_s
  response = conn.get do |req|
    req.url('search/')
    req.options.params_encoder = Faraday::FlatParamsEncoder
    req.params = {
                   q: [
                        'rdftype:DeprecatedAuthority',
                        'sort:mdate-descending',
                        'rdftype:NameTitle'
                      ],
                   format: 'atom',
                   start: offset }
  end
  doc = Nokogiri::XML(response.body)
  entries = doc.xpath('//xmlns:entry')
  last_entry = entries[-1]
  last_mod = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_mod).to_time
  do_next = last_entry_time > naf_last_dump
  entries.each do |entry|
    links = entry.xpath("xmlns:link[@rel='alternate']")
    uri_entry = links.select { |link| link['href'] =~ /^.*\/[0-9a-z]+$/ }.first
    next unless uri_entry
    uri = uri_entry['href']
    delete_uris << uri
  end
  break unless do_next
end

### LCSH simple deletes
0.upto(2000) do |page_num|
  offset = ((page_num * 20) + 1).to_s
  response = conn.get do |req|
    req.url('search/')
    req.options.params_encoder = Faraday::FlatParamsEncoder
    req.params = {
                   q: [
                        'rdftype:DeprecatedAuthority',
                        'sort:mdate-descending',
                        'rdftype:Topic'
                      ],
                   format: 'atom',
                   start: offset }
  end
  doc = Nokogiri::XML(response.body)
  entries = doc.xpath('//xmlns:entry')
  last_entry = entries[-1]
  last_mod = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_mod).to_time
  do_next = last_entry_time > lcsh_last_dump
  entries.each do |entry|
    links = entry.xpath("xmlns:link[@rel='alternate']")
    uri_entry = links.select { |link| link['href'] =~ /^.*\/[0-9a-z]+$/ }.first
    next unless uri_entry
    uri = uri_entry['href']
    delete_uris << uri
  end
  break unless do_next
end

### LCSH complex deletes
0.upto(2000) do |page_num|
  offset = ((page_num * 20) + 1).to_s
  response = conn.get do |req|
    req.url('search/')
    req.options.params_encoder = Faraday::FlatParamsEncoder
    req.params = {
                   q: [
                        'rdftype:DeprecatedAuthority',
                        'sort:mdate-descending',
                        'rdftype:ComplexSubject'
                      ],
                   format: 'atom',
                   start: offset }
  end
  doc = Nokogiri::XML(response.body)
  entries = doc.xpath('//xmlns:entry')
  last_entry = entries[-1]
  last_mod = last_entry.at_xpath('xmlns:updated').text
  last_entry_time = DateTime.strptime(last_mod).to_time
  do_next = last_entry_time > lcsh_last_dump
  entries.each do |entry|
    links = entry.xpath("xmlns:link[@rel='alternate']")
    uri_entry = links.select { |link| link['href'] =~ /^.*\/[0-9a-z]+$/ }.first
    next unless uri_entry
    uri = uri_entry['href']
    delete_uris << uri
  end
  break unless do_next
end
