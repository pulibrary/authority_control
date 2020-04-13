def lc_conn
  Faraday.new(url: 'http://id.loc.gov') do |faraday|
    faraday.request   :url_encoded
    faraday.response  :logger
    faraday.adapter   Faraday.default_adapter
  end
end
