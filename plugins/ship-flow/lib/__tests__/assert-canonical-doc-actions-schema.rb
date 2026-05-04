#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

schema_path = ARGV.fetch(0) do
  warn "Usage: assert-canonical-doc-actions-schema.rb <entity-body-schema.yaml>"
  exit 2
end

schema = YAML.safe_load(File.read(schema_path), permitted_classes: [Symbol], aliases: true)
errors = []

def dig_hash(value, *keys)
  keys.reduce(value) do |memo, key|
    return nil unless memo.is_a?(Hash)

    memo[key]
  end
end

def expect_equal(errors, label, actual, expected)
  return if actual == expected

  errors << "#{label}: expected #{expected.inspect}, got #{actual.inspect}"
end

def expect_includes(errors, label, actual, expected_fragment)
  unless actual.to_s.include?(expected_fragment)
    errors << "#{label}: expected to include #{expected_fragment.inspect}, got #{actual.inspect}"
  end
end

plan_action_field = dig_hash(
  schema,
  "stages", "plan", "output", "subsections", "canonical_doc_actions", "fields"
)&.find { |field| field["name"] == "canonical_doc_actions" }

review_consumed_field = dig_hash(
  schema,
  "stages", "review", "output", "subsections", "canonical_doc_actions_consumed", "fields"
)&.find { |field| field["name"] == "action_matrix" }

expect_equal(errors, "plan canonical_doc_actions type", plan_action_field&.fetch("type", nil), "table")
expect_equal(
  errors,
  "plan canonical_doc_actions columns",
  plan_action_field&.fetch("columns", nil),
  ["Doc", "Action", "Source", "Rationale"]
)
expect_equal(
  errors,
  "plan canonical_doc_actions allowed_docs",
  plan_action_field&.fetch("allowed_docs", nil),
  ["ROADMAP.md", "PRODUCT.md", "ARCHITECTURE.md"]
)
expect_equal(
  errors,
  "plan canonical_doc_actions allowed_actions",
  plan_action_field&.fetch("allowed_actions", nil),
  ["update", "skip"]
)
expect_equal(
  errors,
  "plan canonical_doc_actions allowed_sources",
  plan_action_field&.fetch("allowed_sources", nil),
  ["spec", "design", "plan", "touched-files"]
)

plan_rules = plan_action_field&.fetch("rules", nil) || []
expect_includes(errors, "plan canonical_doc_actions exact-row rule", plan_rules.join("\n"), "Every doc must have exactly one action row")
expect_includes(errors, "plan canonical_doc_actions skip rule", plan_rules.join("\n"), "Action=skip requires a concrete rationale")
expect_includes(errors, "plan canonical_doc_actions update rule", plan_rules.join("\n"), "Action=update must be consumed by ship-review")

expect_equal(errors, "review canonical_doc_actions_consumed type", review_consumed_field&.fetch("type", nil), "table")
expect_equal(
  errors,
  "review canonical_doc_actions_consumed columns",
  review_consumed_field&.fetch("columns", nil),
  ["Doc", "Action Source", "Plan Action", "Review Outcome", "Commit Or Skip Rationale"]
)

review_rules = review_consumed_field&.fetch("rules", nil) || []
expect_includes(errors, "review consumed every-row rule", review_rules.join("\n"), "Every plan canonical_doc_actions row appears exactly once")
expect_includes(errors, "review consumed update rule", review_rules.join("\n"), "Plan Action=update must map to a commit/outcome")
expect_includes(errors, "review consumed skip rule", review_rules.join("\n"), "Plan Action=skip must carry the skip rationale")

if errors.any?
  warn "canonical doc action schema contract failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

puts "canonical doc action schema contract OK"
