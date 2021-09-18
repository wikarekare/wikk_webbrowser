module WIKK
  require 'net/http'
  require 'net/https'
  require 'uri'
  require 'cgi'
  require 'nokogiri'
  require 'base64'
  require 'wikk_json'

  # WIKK WebBrowser class under MIT Lic. https://github.com/wikarekare.
  # Wrapper around ruby's http classes
  #  WIKK_WebBrowser.new.https_session(host: 'www.blah.com') do |session|
  #    response = get_page(query: ,'/')
  #  end

  class WebBrowser
    VERSION = '0.9.5'

    class Error < RuntimeError
      attr_accessor :web_return_code

      def initialize(web_return_code:, message:)
        super(message)
        @web_return_code = web_return_code
      end
    end

    attr_reader :host
    attr_accessor :session
    attr_accessor :cookies
    attr_reader :page
    attr_accessor :referer
    attr_accessor :debug
    attr_accessor :verify_cert
    attr_accessor :port
    attr_accessor :use_ssl
    attr_accessor :response

    # Create a WIKK_WebBrowser instance
    #
    # @param host [String] the host we want to connect to
    # @param port [Fixnum] Optional http server port
    # @param use_ssl [Boolean] Use https, if true
    # @param verify_cert [Boolean] Validate certificate if true (Nb lots of embedded devices have self signed certs, so verify will fail)
    # @return [WIKK_WebBrowser]
    #
    def initialize(host:, port: nil, use_ssl: false, cookies: {}, verify_cert: true, debug: false)
      @host = host # Need to do this, as passing nil is different to passing nothing to initialize!
      @cookies = cookies.nil? ? {} : cookies
      @debug = debug
      @use_ssl = use_ssl
      @port = port.nil? ? ( use_ssl ? 443 : 80 ) : port
      @verify_cert = verify_cert
      @response = nil
    end

    # Create a WIKK_WebBrowser instance, connect to the host via http, and yield the WIKK_WebBrowser instance.
    # Automatically closes the http session on returning from the block passed to it.
    #
    # @param host [String] the host we want to connect to
    #
    # @param port [Fixnum] (80) the port the remote web server is running on
    #
    # @param block [Proc]
    #
    # @yieldparam [WIKK_WebBrowser] the session descriptor for further calls.
    #
    def self.http_session(host:, port: nil, debug: false, cookies: {})
      wb = self.new(host: host, port: port, debug: debug, use_ssl: false, cookies: cookies)
      wb.http_session do
        yield wb
      end
    end

    # Create a WIKK_WebBrowser instance, connect to the host via https, and yield the WIKK_WebBrowser instance.
    #  Automatically closes the http session on returning from the block passed to it.
    # @param host [String] the host we want to connect to
    # @param port [Fixnum] (443) the port the remote web server is running on
    # @param verify_cert [Boolean] Validate certificate if true (Nb lots of embedded devices have self signed certs, so verify will fail)
    # @param block [Proc]
    # @yieldparam [WIKK_WebBrowser] the session descriptor for further calls.
    def self.https_session(host:, port: nil, verify_cert: true, cookies: {}, debug: false)
      wb = self.new(host: host, port: port, cookies: cookies, use_ssl: true, verify_cert: verify_cert, debug: debug)
      wb.http_session do
        yield wb
      end
    end

    # Creating a session for http connection
    # attached block would then call get or post NET::HTTP calls
    # @param port [Fixnum] Optional http server port
    # @param use_ssl [Boolean] Use https, if true
    # @param verify_cert [Boolean] Validate certificate if true (Nb lots of embedded devices have self signed certs, so verify will fail)
    # @param block [Proc]
    def http_session
      @http = Net::HTTP.new(@host, @port)
      @http.set_debug_output($stdout) if @debug
      @http.use_ssl = @use_ssl
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ! @use_ssl || ! @verify_cert
      @http.start do |session| # ensure we close the session after the block
        @session = session
        yield
      end
    end

    # Web basic authentication (not exactly secure)
    # @param user [String] Account name
    # @param password [String] Accounts password
    # @return [String] Base64 encoded concatentation of user + ':' + password
    def basic_authorization(user:, password:)
      # req.basic_auth( user, password) if  user != nil
      'Basic ' + Base64.encode64( "#{user}:#{password}" )
    end

    # Dropbox style token authentication
    # @param token [String] Token, as issued by dropbox
    # @return [String] Concatenation of 'Bearer ' + token
    def bearer_authorization(token:)
      'Bearer ' + token
    end

    # Add additional cookies
    # @param cookies [Hash] cookie_name => cookie_value
    def add_cookies(cookies)
      cookies.each { |cookie_name, cookie_value| @cookies[cookie_name] = cookie_value }
    end

    # Save cookies returned by last html get/post.
    # Removes previous cookies.
    # @param response [Net::HTTPResponse] result from HTTP calls
    def save_cookies(response)
      if (cookie_lines = response.get_fields('set-cookie')) != nil
        cookie_lines.each do |cookie_line|
          cookies = cookie_line.split('; ').map { |v| v.split('=') }
          cookies.each { |c| @cookies[c[0]] = c[1] }
        end
      end
    end

    # Convert @cookies to ; separated strings
    # @return cookies string
    def cookies_to_s
      @cookies.to_a.map { |v| v.join('=') }.join('; ')
    end

    # Get a header value, from the last response
    #
    # @param key [String] header key
    # @return [String] header value, for the given key.
    def header_value(key:)
      @response.header[key]
    end

    # send a GET query to the web server using an http get, and returns the response.
    #  Cookies in the response get preserved in @cookies, so they will be sent along with subsequent calls
    #  We are currently ignoring redirects from the PDU's we are querying.
    # @param query [String] The URL after the http://host/ bit and not usually not including parameters, if form_values are passed in
    # @param form_values [Hash{String=>Object-with-to_s}] The parameter passed to the web server eg. ?key1=value1&key2=value2...
    # @param authorization [String] If present, add Authorization header, using this string
    # @param extra_headers [Hash] Add these to standard headers
    # @param extra_cookies [Hash] Add these to standard cookies
    # @return [String] The Net::HTTPResponse.body text response from the web server
    def get_page(query:, form_values: nil, authorization: nil, extra_headers: {}, extra_cookies: {})
      $stderr.puts 'Debugging On' if @debug
      query += form_values_to_s(form_values, query.index('?') != nil) # Should be using req.set_form_data, but it seems to by stripping the leading / and then the query fails.
      url = URI.parse("#{@use_ssl ? 'https' : 'http'}://#{@host}/#{query.gsub(/^\//, '')}")
      $stderr.puts url if @debug

      req = Net::HTTP::Get.new(url.request_uri)

      header = { 'HOST' => @host }
      header['Accept'] = '*/*'
      header['Accept-Encoding'] = 'gzip, deflate, br'
      header['Accept-Language'] = 'en-US,en;q=0.5'
      header['Connection'] = 'keep-alive'
      header['User-Agent'] = 'Mozilla/5.0'
      header['Content-Type'] = 'application/x-www-form-urlencoded'
      add_cookies(extra_cookies)
      header['Cookie'] = cookies_to_s if @cookies.length > 0
      header['DNT'] = '1'
      header['Authorization'] = authorization if authorization != nil

      extra_headers.each do |k, v|
        header[k] = v
      end

      req.initialize_http_header( header )

      @response = @session.request(req)
      save_cookies(@response)

      $stderr.puts @response.code.to_i if @debug

      if @response.code.to_i >= 300
        if @response.code.to_i == 302
          # ignore the redirects.
          # $stderr.puts "302"
          # @response.each {|key, val| $stderr.printf "%s = %s\n", key, val }  #Location seems to have cgi params removed. End up with .../cginame?&
          # $stderr.puts "Redirect to #{@response['location']}"   #Location seems to have cgi params removed. End up with .../cginame?&
          # $stderr.puts
          return
        elsif @response.code.to_i >= 400 && @response.code.to_i < 500
          return @response.body
        end

        raise Error.new(web_return_code: @response.code.to_i, message: "#{@response.code} #{@response.message} #{query} #{form_values} #{@response.body}")
      end

      return @response.body
    end

    # send a POST query to the server and return the response.
    # @param query [String] URL, less the 'http://host/'  part
    # @param authorization [String] If present, add Authorization header, using this string
    # @param content_type [String] Posted content type
    # @param data [String] Text to add to body of post to the web server
    # @param extra_headers [Hash] Add these to standard headers
    # @param extra_cookies [Hash] Add these to standard cookies
    # @return [String] The Net::HTTPResponse.body text response from the web server
    def post_page(query:, authorization: nil, content_type: 'application/x-www-form-urlencoded', data: nil, extra_headers: {}, extra_cookies: {})
      url = URI.parse("#{@use_ssl ? 'https' : 'http'}://#{@host}/#{query}")
      req = Net::HTTP::Post.new(url.path)

      header = { 'HOST' => @host }
      header['Accept'] = '*/*'
      header['Accept-Encoding'] = 'gzip, deflate, br'
      header['Accept-Language'] = 'en-US,en;q=0.5'
      header['Connection'] = 'keep-alive'
      header['User-Agent'] = 'Mozilla/5.0'
      header['Content-Type'] = content_type
      add_cookies(extra_cookies)
      header['Cookie'] = cookies_to_s if @cookies.length > 0
      header['DNT'] = '1'
      header['Authorization'] = authorization if authorization != nil

      extra_headers.each do |k, v|
        header[k] = v
      end
      req.initialize_http_header( header )

      if data.nil?
        req.body = ''
      elsif data.instance_of?(Hash)
        if content_type =~ /application\/octet-stream/
          req.set_form_data(data, '&')
        else
          req.set_form_data.to_j
        end
      else
        req.body = data # If json as a string or raw string
      end

      @response = @session.request(req)
      save_cookies(@response)

      if @response.code.to_i >= 300
        if @response.code.to_i == 302
          # ignore the redirects.
          # puts "302"
          # @response.each {|key, val| printf "%s = %s\n", key, val }  #Location seems to have cgi params removed. End up with .../cginame?&
          # puts "Redirect of Post to #{@response['location']}" #Location seems to have cgi params removed. End up with .../cginame?&
          return
        end

        raise Error.new(web_return_code: @response.code, message: "#{@response.code} #{@response.message} #{query} #{data} #{@response.body}")
      end

      return @response.body
    end

    # send a DELETE query to the server and return the response.
    # @param query [String] URL, less the 'http://host/'  part
    # @param authorization [String] If present, add Authorization header, using this string
    # @param extra_headers [Hash] Add these to standard headers
    # @param extra_cookies [Hash] Add these to standard cookies
    # @return [String] The Net::HTTPResponse.body text response from the web server
    def delete_req(query:, authorization: nil, extra_headers: {}, extra_cookies: {})
      url = URI.parse("#{@use_ssl ? 'https' : 'http'}://#{@host}/#{query.gsub(/^\//, '')}")
      req = Net::HTTP::Delete.new(query)

      header = { 'HOST' => @host }
      add_cookies(extra_cookies)
      header['Cookie'] = cookies_to_s if @cookies.length > 0
      header['Authorization'] = authorization if authorization != nil

      extra_headers.each do |k, v|
        header[k] = v
      end
      req.initialize_http_header( header )

      begin
        @response = @session.request(req)
        save_cookies(@response)

        if @response.code.to_i >= 300
          raise "#{url} : #{@response.code} #{@response.message}"
        end

        return @response.body
      rescue StandardError => e
        puts "#{e}"
        return nil
      end
    end

    # send a PUT query to the server and return the response.
    # @param query [String] URL, less the 'http://host/'  part
    # @param authorization [String] If present, add Authorization header, using this string
    # @param content_type [String] Posted content type
    # @param data [String] Text to add to body of post to the web server
    # @param extra_headers [Hash] Add these to standard headers
    # @param extra_cookies [Hash] Add these to standard cookies
    # @return [String] The Net::HTTPResponse.body text response from the web server
    def put_req(query:, authorization: nil, content_type: '"application/octet-stream"', data: nil, extra_headers: {}, extra_cookies: {})
      url = URI.parse("#{@use_ssl ? 'https' : 'http'}://#{@host}/#{query}")
      req = Net::HTTP::Put.new(url.path)

      header = { 'HOST' => @host }
      header['Accept'] = '*/*'
      header['Accept-Encoding'] = 'gzip, deflate, br'
      header['Accept-Language'] = 'en-US,en;q=0.5'
      header['Connection'] = 'keep-alive'
      header['User-Agent'] = 'Mozilla/5.0'
      header['Content-Type'] = content_type
      add_cookies(extra_cookies)
      header['Cookie'] = cookies_to_s if @cookies.length > 0
      header['DNT'] = '1'
      header['Authorization'] = authorization if authorization != nil

      extra_headers.each do |k, v|
        header[k] = v
      end
      req.initialize_http_header( header )

      if data.nil?
        req.body = ''
      elsif data.instance_of?(Hash)
        if content_type =~ /application\/octet-stream/
          req.set_form_data(data, '&')
        else
          req.set_form_data.to_j
        end
      else
        req.body = data # If json as a string or raw string
      end

      @response = @session.request(req)
      save_cookies(@response)

      if @response.code.to_i >= 300
        if @response.code.to_i == 302
          # ignore the redirects.
          # puts "302"
          # @response.each {|key, val| printf "%s = %s\n", key, val }  #Location seems to have cgi params removed. End up with .../cginame?&
          # puts "Redirect of Post to #{@response['location']}" #Location seems to have cgi params removed. End up with .../cginame?&
          return
        end

        raise Error.new(web_return_code: @response.code, message: "#{@response.code} #{@response.message} #{query} #{data} #{@response.body}")
      end

      return @response.body
    end

    # Extract form field values from the html body.
    # @param body [String] The html response body
    # @return [Hash] Keys are the field names, values are the field values
    def extract_input_fields(body)
      entry = true
      @inputs = {}
      doc = Nokogiri::HTML(body)
      doc.xpath('//form/input').each do |f|
        @inputs[f.get_attribute('name')] = f.get_attribute('value')
      end
    end

    # Extract links from the html body.
    # @param body [String] The html response body
    # @return [Hash] Keys are the link text, values are the html links
    def extract_link_fields(body)
      entry = true
      @inputs = {}
      doc = Nokogiri::HTML(body)
      doc.xpath('//a').each do |f|
        return URI.parse( f.get_attribute('href') ).path if f.get_attribute('name') == 'URL$1'
      end
      return nil
    end

    # Take a hash of the params to the post and generate a safe URL string.
    # @param form_values [Hash] Keys are the field names, values are the field values
    # @param has_q [Boolean] We have a leading ? for the html get, so don't need to add one.
    # @return [String] The 'safe' text for fields the get or post query to the web server
    def form_values_to_s(form_values = nil, has_q = false)
      return '' if form_values.nil? || form_values.length == 0

      s = (has_q == true ? '' : '?')
      first = true
      form_values.each do |key, value|
        s += '&' unless first
        s += "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
        first = false
      end
      return s
    end
  end
end
