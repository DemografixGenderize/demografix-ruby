# frozen_string_literal: true

# Summarize the demographic mix of a list of names.
#
# Run with: ruby examples/demographic_mix.rb
# Set DEMOGRAFIX_API_KEY to your API key. One key works across all three services.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "demografix"

client = Demografix::Client.new(api_key: ENV.fetch("DEMOGRAFIX_API_KEY"))

names = %w[michael matthew jane emily peter lois]

# Gender split across the list.
genders = client.genderize_batch(names)
split = genders.results.each_with_object(Hash.new(0)) do |pred, counts|
  counts[pred.gender || "unknown"] += 1
end

# Age distribution across the list.
ages = client.agify_batch(names)
known_ages = ages.results.map(&:age).compact
average_age = known_ages.empty? ? nil : (known_ages.sum.to_f / known_ages.length).round(1)

# Nationality mix: the top country guessed for each name.
nationalities = client.nationalize_batch(names)
top_countries = nationalities.results.each_with_object(Hash.new(0)) do |pred, counts|
  top = pred.country.first
  counts[top ? top.country_id : "unknown"] += 1
end

puts "Names analyzed: #{names.length}"
puts "Gender split:   #{split.sort_by { |_, n| -n }.map { |g, n| "#{g}=#{n}" }.join(', ')}"
puts "Average age:    #{average_age || 'n/a'}"
puts "Top countries:  #{top_countries.sort_by { |_, n| -n }.map { |c, n| "#{c}=#{n}" }.join(', ')}"
puts "Quota remaining: #{genders.quota.remaining}"
