# frozen_string_literal: true

module Demografix
  # Base class for every error the SDK raises. Carries the HTTP status (when
  # one is known), the server-provided message, and the quota parsed from the
  # rate-limit headers (when present).
  class Error < StandardError
    attr_reader :status, :quota

    def initialize(message = nil, status: nil, quota: nil)
      super(message)
      @status = status
      @quota = quota
    end
  end

  # 401 — the API key is missing or invalid.
  class AuthError < Error; end

  # 402 — the subscription is not active (expired freebie or inactive plan).
  class SubscriptionError < Error; end

  # 422 — the request parameters are invalid. Also raised client-side, before
  # any HTTP call, when a batch contains more than the maximum number of names.
  class ValidationError < Error; end

  # 429 — the request limit for the current window is reached. Read
  # quota.reset for the seconds to wait before retrying.
  class RateLimitError < Error; end

  # Network failure, timeout, or a response body that is not valid JSON.
  # status and quota may be absent.
  class TransportError < Error; end
end
