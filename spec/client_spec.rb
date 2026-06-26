# frozen_string_literal: true

require "json"

RSpec.describe Demografix::Client do
  subject(:client) { described_class.new(api_key: "test-key") }

  def stub_ok(host, body, headers: RATE_LIMIT_HEADERS)
    stub_request(:get, /#{Regexp.escape(host)}/)
      .to_return(status: 200, body: JSON.dump(body), headers: headers)
  end

  def stub_error(host, status, body, headers: RATE_LIMIT_HEADERS)
    stub_request(:get, /#{Regexp.escape(host)}/)
      .to_return(status: status, body: JSON.dump(body), headers: headers)
  end

  # (1) single parse + quota.remaining == 24987 ---------------------------------

  describe "#genderize" do
    it "parses the prediction fields and quota" do
      stub_ok("api.genderize.io",
              { "count" => 1_352_696, "name" => "peter", "gender" => "male",
                "probability" => 1.0 })

      result = client.genderize("peter")

      expect(result.name).to eq("peter")
      expect(result.gender).to eq("male")
      expect(result.probability).to eq(1.0)
      expect(result.count).to eq(1_352_696)
      expect(result.country_id).to be_nil
      expect(result.quota.limit).to eq(25_000)
      expect(result.quota.remaining).to eq(24_987)
      expect(result.quota.reset).to eq(1_314_000)
    end

    it "requests name=<v> for a single name and sends the User-Agent" do
      stub_ok("api.genderize.io",
              { "name" => "peter", "gender" => "male", "probability" => 1.0,
                "count" => 1 })

      client.genderize("peter")

      expect(a_request(:get, "https://api.genderize.io/")
        .with(query: { "name" => "peter", "apikey" => "test-key" },
              headers: { "User-Agent" => "demografix-ruby/0.1.0" })).to have_been_made
    end
  end

  describe "#agify" do
    it "parses the prediction fields and quota" do
      stub_ok("api.agify.io",
              { "count" => 311_558, "name" => "michael", "age" => 57 })

      result = client.agify("michael")

      expect(result.name).to eq("michael")
      expect(result.age).to eq(57)
      expect(result.count).to eq(311_558)
      expect(result.quota.remaining).to eq(24_987)
    end
  end

  describe "#nationalize" do
    it "parses the country candidates and quota" do
      stub_ok("api.nationalize.io",
              { "count" => 100_783, "name" => "nguyen",
                "country" => [
                  { "country_id" => "VN", "probability" => 0.891132 },
                  { "country_id" => "MO", "probability" => 0.019031 }
                ] })

      result = client.nationalize("nguyen")

      expect(result.name).to eq("nguyen")
      expect(result.country.length).to eq(2)
      expect(result.country.first.country_id).to eq("VN")
      expect(result.country.first.probability).to eq(0.891132)
      expect(result.count).to eq(100_783)
      expect(result.quota.remaining).to eq(24_987)
    end
  end

  # (2) batch — order + quota ---------------------------------------------------

  describe "#agify_batch" do
    it "parses results in input order with one quota" do
      stub_ok("api.agify.io",
              [{ "count" => 311_558, "name" => "michael", "age" => 57 },
               { "count" => 55_682, "name" => "matthew", "age" => 48 }])

      batch = client.agify_batch(%w[michael matthew])

      expect(batch.results.map(&:name)).to eq(%w[michael matthew])
      expect(batch.results.map(&:age)).to eq([57, 48])
      expect(batch.quota.remaining).to eq(24_987)
    end

    it "sends repeated name[]=<v> params for a batch" do
      stub_ok("api.agify.io",
              [{ "name" => "michael", "age" => 57, "count" => 1 },
               { "name" => "matthew", "age" => 48, "count" => 1 }])

      client.agify_batch(%w[michael matthew])

      expect(a_request(:get, "https://api.agify.io/?name[]=michael&name[]=matthew&apikey=test-key"))
        .to have_been_made
    end
  end

  # (3) null prediction — no error ---------------------------------------------

  describe "null predictions" do
    it "returns a null gender without raising" do
      stub_ok("api.genderize.io",
              { "name" => "xÿz", "gender" => nil, "probability" => 0.0, "count" => 0 })

      result = client.genderize("xÿz")

      expect(result.gender).to be_nil
      expect(result.probability).to eq(0.0)
      expect(result.count).to eq(0)
    end

    it "returns a null age without raising" do
      stub_ok("api.agify.io", { "name" => "xÿz", "age" => nil, "count" => 0 })

      result = client.agify("xÿz")

      expect(result.age).to be_nil
    end

    it "returns an empty country list without raising" do
      stub_ok("api.nationalize.io", { "name" => "xÿz", "country" => [], "count" => 0 })

      result = client.nationalize("xÿz")

      expect(result.country).to eq([])
    end
  end

  # (4) country_id round-trip ---------------------------------------------------

  describe "country_id" do
    it "sends country_id and parses it back" do
      stub_ok("api.genderize.io",
              { "count" => 196_601, "name" => "kim", "gender" => "female",
                "country_id" => "US", "probability" => 0.94 })

      result = client.genderize("kim", country_id: "US")

      expect(result.country_id).to eq("US")
      expect(result.gender).to eq("female")
      expect(a_request(:get, "https://api.genderize.io/")
        .with(query: { "name" => "kim", "country_id" => "US", "apikey" => "test-key" })).to have_been_made
    end

    it "carries country_id on agify batches" do
      stub_ok("api.agify.io",
              [{ "name" => "kim", "age" => 40, "count" => 1, "country_id" => "US" }])

      client.agify_batch(%w[kim], country_id: "us")

      expect(a_request(:get, "https://api.agify.io/?name[]=kim&country_id=us&apikey=test-key"))
        .to have_been_made
    end
  end

  # (5) batch of 11 — ValidationError, no HTTP ----------------------------------

  describe "client-side batch validation" do
    it "raises ValidationError for more than 10 names without any HTTP call" do
      stub = stub_request(:get, /api\.agify\.io/)

      names = (1..11).map { |i| "name#{i}" }

      expect { client.agify_batch(names) }.to raise_error(Demografix::ValidationError) do |e|
        expect(e.status).to eq(422)
        expect(e.message).to include("at most 10")
      end
      expect(stub).not_to have_been_requested
    end

    it "allows exactly 10 names" do
      stub_ok("api.agify.io", (1..10).map { |i| { "name" => "n#{i}", "age" => i, "count" => 1 } })

      batch = client.agify_batch((1..10).map { |i| "n#{i}" })

      expect(batch.results.length).to eq(10)
    end
  end

  # (6) error mapping -----------------------------------------------------------

  describe "error mapping" do
    {
      401 => [Demografix::AuthError, "Invalid API key"],
      402 => [Demografix::SubscriptionError, "Subscription is not active"],
      422 => [Demografix::ValidationError, "Missing 'name' parameter"],
      429 => [Demografix::RateLimitError, "Request limit reached"]
    }.each do |status, (klass, message)|
      it "maps #{status} to #{klass} carrying status, message, and quota" do
        stub_error("api.genderize.io", status, { "error" => message })

        expect { client.genderize("peter") }.to raise_error(klass) do |e|
          expect(e).to be_a(Demografix::Error)
          expect(e.status).to eq(status)
          expect(e.message).to eq(message)
          expect(e.quota).not_to be_nil
          expect(e.quota.remaining).to eq(24_987)
        end
      end
    end

    it "maps other non-2xx statuses to the base error" do
      stub_error("api.genderize.io", 500, { "error" => "Server error" })

      expect { client.genderize("peter") }.to raise_error(Demografix::Error) do |e|
        expect(e.status).to eq(500)
        expect(e.message).to eq("Server error")
      end
    end

    it "raises TransportError on a non-JSON body" do
      stub_request(:get, /api\.genderize\.io/)
        .to_return(status: 200, body: "<html>nope</html>", headers: RATE_LIMIT_HEADERS)

      expect { client.genderize("peter") }.to raise_error(Demografix::TransportError)
    end

    it "raises TransportError on a network timeout" do
      stub_request(:get, /api\.genderize\.io/).to_timeout

      expect { client.genderize("peter") }.to raise_error(Demografix::TransportError)
    end
  end

  # apikey ----------------------------------------------------------------------

  describe "api key" do
    it "always sends the apikey query parameter" do
      stub_ok("api.genderize.io",
              { "name" => "peter", "gender" => "male", "probability" => 1.0, "count" => 1 })

      client.genderize("peter")

      expect(a_request(:get, "https://api.genderize.io/")
        .with(query: hash_including("apikey" => "test-key"))).to have_been_made
    end

    it "sends the configured key as apikey" do
      keyed = described_class.new(api_key: "SECRET")
      stub_ok("api.genderize.io",
              { "name" => "peter", "gender" => "male", "probability" => 1.0, "count" => 1 })

      keyed.genderize("peter")

      expect(a_request(:get, "https://api.genderize.io/")
        .with(query: { "name" => "peter", "apikey" => "SECRET" })).to have_been_made
    end

    it "raises ValidationError when constructed with a missing or blank key, making no HTTP call" do
      stub = stub_request(:get, /api\.genderize\.io/)

      [nil, "", "   "].each do |bad|
        expect { described_class.new(api_key: bad) }
          .to raise_error(Demografix::ValidationError, /api_key is required/)
      end

      # Fully omitting the keyword raises Ruby's native missing-argument error.
      expect { described_class.new }.to raise_error(ArgumentError)

      expect(stub).not_to have_been_requested
    end
  end
end
