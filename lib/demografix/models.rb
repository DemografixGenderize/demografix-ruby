# frozen_string_literal: true

module Demografix
  # The rate-limit window, parsed from the x-rate-limit-* response headers.
  Quota = Data.define(:limit, :remaining, :reset)

  # One nationalize candidate: a country and its probability.
  NationalizeCountry = Data.define(:country_id, :probability)

  # A single genderize prediction. country_id is set only when the request
  # carried one.
  GenderizePrediction = Data.define(:name, :gender, :probability, :count, :country_id)

  # A single agify prediction. country_id is set only when the request carried
  # one.
  AgifyPrediction = Data.define(:name, :age, :count, :country_id)

  # A single nationalize prediction. country is an array of NationalizeCountry,
  # descending by probability, possibly empty.
  NationalizePrediction = Data.define(:name, :country, :count)

  # A single-name result: every prediction field plus a quota reader.
  GenderizeResult = Data.define(:name, :gender, :probability, :count, :country_id, :quota)
  AgifyResult = Data.define(:name, :age, :count, :country_id, :quota)
  NationalizeResult = Data.define(:name, :country, :count, :quota)

  # A batch result: the per-name predictions plus one quota for the response.
  Batch = Data.define(:results, :quota)
end
