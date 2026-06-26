# demografix (Ruby)

Run demographic analysis over names — predicted gender, age, and nationality — from one Ruby client. The
gem covers genderize.io, agify.io, and nationalize.io.

## Install

Add the gem to your Gemfile:

```ruby
gem "demografix"
```

Then run `bundle install`. To install directly:

```sh
gem install demografix
```

The client uses the Ruby standard library (`net/http` and `json`) and has no runtime dependencies. It requires Ruby 3.2 or later.

## Authentication

An API key is required. Creating one is free and includes 2,500 requests per month. Generate a key in your
dashboard at genderize.io, agify.io, or nationalize.io. One key works across all three services.

## Quickstart

Construct a client, run a batch over a list of names, read the predictions, and read the remaining quota.

```ruby
require "demografix"

client = Demografix::Client.new(api_key: ENV.fetch("DEMOGRAFIX_API_KEY"))

names = %w[michael matthew jane emily peter lois]

ages = client.agify_batch(names)

# Aggregate the predictions into an age distribution for the list.
known = ages.results.map(&:age).compact
average_age = known.sum.to_f / known.length

ages.quota.remaining # => 24987
```

Each call returns prediction fields plus a `quota`. Batch calls return `results` (one prediction per input
name, in input order) plus one `quota` for the response. Aggregate the results into a distribution; the
client is built to summarize a list, not to label an individual.

## genderize

Predict gender from a name.

```ruby
result = client.genderize("peter")
result.gender      # => "male"
result.probability # => 1.0
result.count       # => 1352696
```

Batch a list and reduce it to a gender split:

```ruby
batch = client.genderize_batch(%w[peter lois meg chris])
split = batch.results.each_with_object(Hash.new(0)) do |pred, counts|
  counts[pred.gender || "unknown"] += 1
end
# => { "male" => 2, "female" => 2 }
```

`gender` is `"male"`, `"female"`, or `nil`. A name with no match returns `nil` gender, `0.0` probability,
and `0` count. That is a successful response, not an error.

## agify

Predict age from a name.

```ruby
result = client.agify("michael")
result.age   # => 57
result.count # => 311558
```

Batch a list and reduce it to an age distribution:

```ruby
batch = client.agify_batch(%w[michael matthew jane])
ages = batch.results.map(&:age).compact
buckets = ages.group_by { |age| (age / 10) * 10 }
# => { 50 => [57], 40 => [48], ... }
```

`age` is an integer or `nil`. A name with no match returns `nil` age and `0` count.

## nationalize

Predict nationality from a name.

```ruby
result = client.nationalize("nguyen")
result.country.first.country_id   # => "VN"
result.country.first.probability  # => 0.891132
```

Batch a list and reduce it to a nationality mix:

```ruby
batch = client.nationalize_batch(%w[nguyen schmidt rossi])
mix = batch.results.each_with_object(Hash.new(0)) do |pred, counts|
  top = pred.country.first
  counts[top ? top.country_id : "unknown"] += 1
end
# => { "VN" => 1, "DE" => 1, "IT" => 1 }
```

`country` holds up to five candidates in descending probability order. A name with no match returns an empty
`country` array.

## country_id

`genderize` and `agify` accept an optional `country_id` (ISO 3166-1 alpha-2) to scope the prediction to a
country. `nationalize` does not accept it.

```ruby
result = client.genderize("kim", country_id: "US")
result.country_id # => "US"
result.gender     # => "female"

client.agify_batch(%w[andrea andrea], country_id: "IT")
```

The value is echoed back uppercase in `country_id` on each prediction. When the request sends no
`country_id`, the field is `nil`.

## Quota

Every result and every raised error carries a `quota` read from the response rate-limit headers:

| Field | Meaning |
|---|---|
| `limit` | names allowed in the current window |
| `remaining` | names left in the current window |
| `reset` | seconds until the window resets |

```ruby
result = client.genderize("peter")
result.quota.limit     # => 25000
result.quota.remaining # => 24987
result.quota.reset     # => 1314000
```

Read quota off the returned value or a raised error. The client does not cache it.

## Errors

Every error subclasses `Demografix::Error` and carries `status`, `message`, and `quota` (when the response
included rate-limit headers).

| Error | Raised on |
|---|---|
| `Demografix::AuthError` | 401, invalid or missing API key |
| `Demografix::SubscriptionError` | 402, subscription not active |
| `Demografix::ValidationError` | 422, invalid parameters; also client-side for a batch over 10 names |
| `Demografix::RateLimitError` | 429, request limit reached (quota always populated) |
| `Demografix::TransportError` | network failure, timeout, or non-JSON body |
| `Demografix::Error` | any other non-2xx status |

A batch of more than 10 names raises `ValidationError` before any HTTP call is made.

On a `RateLimitError`, read `quota.reset` for the seconds to wait before retrying:

```ruby
begin
  client.genderize_batch(names)
rescue Demografix::RateLimitError => e
  sleep(e.quota.reset)
  retry
end
```

## Methods

| Method | Returns | country_id |
|---|---|---|
| `genderize(name, country_id:)` | `GenderizeResult` | yes |
| `genderize_batch(names, country_id:)` | `Batch` of `GenderizePrediction` | yes |
| `agify(name, country_id:)` | `AgifyResult` | yes |
| `agify_batch(names, country_id:)` | `Batch` of `AgifyPrediction` | yes |
| `nationalize(name)` | `NationalizeResult` | no |
| `nationalize_batch(names)` | `Batch` of `NationalizePrediction` | no |

`Demografix::Client.new` requires `api_key:` and accepts `timeout:` (optional, default 10 seconds). The
host URLs and the User-Agent are fixed constants, not options.

Full API reference: https://genderize.io/documentation/api
