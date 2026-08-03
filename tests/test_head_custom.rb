#!/usr/bin/env ruby
# Tests for _includes/head-custom.html — the GoatCounter analytics snippet.
#
# Renders the include through Liquid directly (no full Jekyll build needed) and
# checks that tracking is emitted only when `goatcounter` is configured.
#
# Run:  ruby tests/test_head_custom.rb
# Needs the `liquid` gem:  gem install liquid

begin
  require "liquid"
rescue LoadError
  abort "SKIPPED-AS-FAILURE: the `liquid` gem is not installed. Run `gem install liquid` and re-run."
end

# These files contain UTF-8 (em dashes in comments); don't inherit a
# locale-dependent external encoding.
def read_utf8(path)
  File.read(path, encoding: "UTF-8")
end

ROOT = File.expand_path("..", __dir__)
INCLUDE = File.join(ROOT, "_includes", "head-custom.html")
LAYOUT = File.join(ROOT, "_layouts", "default.html")
CONFIG = File.join(ROOT, "_config.yml")

$failures = []

def check(name)
  ok = yield
  puts(ok ? "ok   - #{name}" : "FAIL - #{name}")
  $failures << name unless ok
rescue => e
  puts "FAIL - #{name} (#{e.class}: #{e.message})"
  $failures << name
end

def render(site)
  Liquid::Template.parse(read_utf8(INCLUDE)).render("site" => site)
end

check("include file exists") { File.exist?(INCLUDE) }

check("layout still includes head-custom.html") do
  read_utf8(LAYOUT).include?("include head-custom.html")
end

check("config defines a goatcounter key") do
  read_utf8(CONFIG).match?(/^goatcounter:/)
end

check("no script when goatcounter is unset") do
  out = render({})
  !out.include?("goatcounter.com") && !out.include?("count.js")
end

check("no script when goatcounter is empty") do
  out = render("goatcounter" => "")
  !out.include?("goatcounter.com") && !out.include?("count.js")
end

check("script emitted with correct endpoint when goatcounter is set") do
  out = render("goatcounter" => "minozzi")
  out.include?('data-goatcounter="https://minozzi.goatcounter.com/count"') &&
    out.include?('src="//gc.zgo.at/count.js"') &&
    out.include?("async")
end

check("no dead Universal Analytics snippet is reintroduced") do
  out = render("goatcounter" => "minozzi", "google_analytics" => "UA-123456-1")
  !out.include?("google-analytics.com") &&
    !out.include?("ga('create'") &&
    !out.include?("gtag")
end

check("include renders no Liquid errors") do
  !render("goatcounter" => "minozzi").include?("Liquid error")
end

puts
if $failures.empty?
  puts "All checks passed."
else
  puts "#{$failures.size} check(s) failed: #{$failures.join(', ')}"
  exit 1
end
