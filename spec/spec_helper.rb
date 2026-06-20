# frozen_string_literal: true

require "demografix"
require "webmock/rspec"

# All network access is disabled; tests stub the HTTP transport by URL pattern.
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# Headers stamped on every Demografix response.
RATE_LIMIT_HEADERS = {
  "x-rate-limit-limit" => "25000",
  "x-rate-limit-remaining" => "24987",
  "x-rate-limit-reset" => "1314000"
}.freeze
