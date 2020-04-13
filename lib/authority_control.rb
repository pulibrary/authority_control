require 'mysql2'
require 'marc'
require 'nokogiri'
require 'faraday'

root_path = File.join(File.dirname(__FILE__), '..')
Dir.glob("#{root_path}/lib/authority_control/*.rb").each do |file|
  require file
end
