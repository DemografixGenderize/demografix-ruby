# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Demografix
  # Synchronous client for the three Demografix APIs: genderize, agify, and
  # nationalize. One instance covers all three services. Quota is read from
  # the returned value or a raised error, never cached on the client.
  class Client
    # Per-service hosts. Hardcoded constants, not options.
    HOSTS = {
      genderize: "https://api.genderize.io",
      agify: "https://api.agify.io",
      nationalize: "https://api.nationalize.io"
    }.freeze

    USER_AGENT = "demografix-ruby/#{VERSION}"

    MAX_BATCH = 10
    DEFAULT_TIMEOUT = 10

    # @param api_key [String, nil] optional. When omitted, requests go out
    #   without apikey (free per-IP tier).
    # @param timeout [Numeric] request timeout in seconds.
    def initialize(api_key: nil, timeout: DEFAULT_TIMEOUT)
      @api_key = api_key
      @timeout = timeout
    end

    # --- genderize ---------------------------------------------------------

    def genderize(name, country_id: nil)
      body, quota = request(:genderize, [name], country_id: country_id, batch: false)
      pred = parse_genderize(single(body))
      GenderizeResult.new(**pred.to_h, quota: quota)
    end

    def genderize_batch(names, country_id: nil)
      body, quota = request(:genderize, validate_batch(names), country_id: country_id, batch: true)
      Batch.new(results: array(body).map { |o| parse_genderize(o) }, quota: quota)
    end

    # --- agify -------------------------------------------------------------

    def agify(name, country_id: nil)
      body, quota = request(:agify, [name], country_id: country_id, batch: false)
      pred = parse_agify(single(body))
      AgifyResult.new(**pred.to_h, quota: quota)
    end

    def agify_batch(names, country_id: nil)
      body, quota = request(:agify, validate_batch(names), country_id: country_id, batch: true)
      Batch.new(results: array(body).map { |o| parse_agify(o) }, quota: quota)
    end

    # --- nationalize -------------------------------------------------------

    def nationalize(name)
      body, quota = request(:nationalize, [name], batch: false)
      pred = parse_nationalize(single(body))
      NationalizeResult.new(**pred.to_h, quota: quota)
    end

    def nationalize_batch(names)
      body, quota = request(:nationalize, validate_batch(names), batch: true)
      Batch.new(results: array(body).map { |o| parse_nationalize(o) }, quota: quota)
    end

    private

    # Validate the batch size client-side before any HTTP call.
    def validate_batch(names)
      list = Array(names)
      if list.length > MAX_BATCH
        raise ValidationError.new(
          "A batch may contain at most #{MAX_BATCH} names, got #{list.length}.",
          status: 422
        )
      end
      list
    end

    # Build and send the request, returning [parsed_body, quota].
    def request(service, names, country_id: nil, batch:)
      uri = URI(HOSTS.fetch(service))
      uri.query = build_query(names, country_id: country_id, batch: batch)
      send_request(uri)
    end

    # Build the query string: name=<v> for a single call, repeated name[]=<v>
    # for a batch. country_id and apikey are added only when set.
    def build_query(names, country_id:, batch:)
      params = []
      if batch
        names.each { |n| params << ["name[]", n.to_s] }
      else
        params << ["name", names.first.to_s]
      end
      params << ["country_id", country_id.to_s] if country_id
      params << ["apikey", @api_key.to_s] if @api_key
      URI.encode_www_form(params)
    end

    # The internal transport seam. Tests stub Net::HTTP at the wire level
    # (webmock); this method performs the real request and is the single point
    # where the network is touched.
    def send_request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT

      response = http.request(req)
      handle(response)
    rescue Timeout::Error, IOError, SocketError, SystemCallError, Net::HTTPBadResponse,
           Net::ProtocolError, OpenSSL::SSL::SSLError => e
      raise TransportError.new(e.message)
    end

    # Map the HTTP response to a parsed body + quota, or raise a typed error.
    def handle(response)
      quota = parse_quota(response)
      code = response.code.to_i
      body = parse_json(response.body)

      return [body, quota] if code.between?(200, 299)

      message = body.is_a?(Hash) ? body["error"] : nil
      message ||= "HTTP #{code}"
      raise error_for(code).new(message, status: code, quota: quota)
    end

    # Select the error class for a status code.
    def error_for(code)
      case code
      when 401 then AuthError
      when 402 then SubscriptionError
      when 422 then ValidationError
      when 429 then RateLimitError
      else Error
      end
    end

    def parse_json(raw)
      return nil if raw.nil? || raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError => e
      raise TransportError.new("Response body is not valid JSON: #{e.message}")
    end

    # Read the rate-limit headers case-insensitively into a Quota. Net::HTTP
    # already normalizes header names to lowercase for lookup.
    def parse_quota(response)
      limit = response["x-rate-limit-limit"]
      remaining = response["x-rate-limit-remaining"]
      reset = response["x-rate-limit-reset"]
      return nil if limit.nil? && remaining.nil? && reset.nil?

      Quota.new(
        limit: to_i_or_nil(limit),
        remaining: to_i_or_nil(remaining),
        reset: to_i_or_nil(reset)
      )
    end

    def to_i_or_nil(value)
      value.nil? ? nil : value.to_i
    end

    def single(body)
      unless body.is_a?(Hash)
        raise TransportError.new("Expected a JSON object, got #{body.class}.")
      end
      body
    end

    def array(body)
      unless body.is_a?(Array)
        raise TransportError.new("Expected a JSON array, got #{body.class}.")
      end
      body
    end

    def parse_genderize(obj)
      GenderizePrediction.new(
        name: obj["name"],
        gender: obj["gender"],
        probability: obj["probability"],
        count: obj["count"],
        country_id: obj["country_id"]
      )
    end

    def parse_agify(obj)
      AgifyPrediction.new(
        name: obj["name"],
        age: obj["age"],
        count: obj["count"],
        country_id: obj["country_id"]
      )
    end

    def parse_nationalize(obj)
      countries = Array(obj["country"]).map do |c|
        NationalizeCountry.new(
          country_id: c["country_id"],
          probability: c["probability"]
        )
      end
      NationalizePrediction.new(
        name: obj["name"],
        country: countries,
        count: obj["count"]
      )
    end
  end
end
