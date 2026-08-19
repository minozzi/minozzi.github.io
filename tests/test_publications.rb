#!/usr/bin/env ruby
# Tests for publications.md, cv.md, and index.md — the site's citation surface.
#
# Guards the failure modes that have actually bitten this site: a DOI whose
# displayed text disagrees with its href, a paper left marked "Accepted" after
# it appeared, a CV link pointing at a PDF that is no longer in the repo, and a
# published paper still sitting in the Working Papers list on the home page.
#
# Pure Ruby, no gems. Run:  ruby tests/test_publications.rb

def read_utf8(path)
  File.read(path, encoding: "UTF-8")
end

ROOT = File.expand_path("..", __dir__)
PUBS = File.join(ROOT, "publications.md")
CVMD = File.join(ROOT, "cv.md")
INDEX = File.join(ROOT, "index.md")
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

pubs = read_utf8(PUBS)

# An entry starts at a bold title line and runs to the next blank-line-separated
# bold title. Splitting on the blank line between entries is enough here because
# every entry is a single unbroken block of lines.
entries = pubs.split(/\n\n+/).select { |b| b.start_with?("**") }

check("publications.md parses into entries") { entries.size >= 20 }

check("every entry carries a DOI link") do
  missing = entries.reject { |e| e.include?("[DOI:") }
                   .map { |e| e.lines.first.strip[0, 60] }
  puts("      missing: #{missing.join(' | ')}") unless missing.empty?
  missing.empty?
end

check("displayed DOI matches its href") do
  bad = pubs.scan(/\[DOI: ([^\]]+)\]\((https?:\/\/doi\.org\/([^)]+))\)/)
            .reject { |text, _url, suffix| text == suffix }
  puts("      mismatched: #{bad.map { |t, u, _| "#{t} -> #{u}" }.join(' | ')}") unless bad.empty?
  bad.empty?
end

check("all DOI links resolve through doi.org over https") do
  pubs.scan(/\[DOI:[^\]]+\]\(([^)]+)\)/).flatten.all? { |u| u.start_with?("https://doi.org/") }
end

check("no paper is left marked as forthcoming without a DOI") do
  stale = entries.select { |e| e.match?(/\b(Accepted|Conditionally accepted|Forthcoming)\b/) }
                 .reject { |e| e.include?("[DOI:") }
  stale.empty?
end

check("the Public Opinion Quarterly paper is listed as published") do
  poq = entries.find { |e| e.include?("Public Opinion Quarterly") }
  !poq.nil? &&
    poq.include?("10.1093/poq/nfag063") &&
    !poq.match?(/\bConditionally accepted\b/)
end

# The CV PDF is date-stamped, so every rebuild renames it. Both the nav link and
# the download button must resolve through site.cv_pdf; a filename written
# straight into a template goes stale the next time the CV is rebuilt, which is
# how the nav came to 404 in Aug 2026.
check("exactly one CV PDF is committed") do
  Dir.glob(File.join(ROOT, "cv-minozzi-*.pdf")).size == 1
end

check("site.cv_pdf names the committed PDF") do
  declared = read_utf8(CONFIG)[/^cv_pdf:\s*\/(\S+)/, 1]
  !declared.nil? && File.exist?(File.join(ROOT, declared))
end

check("no template hardcodes a CV filename") do
  offenders = (Dir.glob(File.join(ROOT, "*.md")) +
               Dir.glob(File.join(ROOT, "_layouts", "*.html")) +
               Dir.glob(File.join(ROOT, "_includes", "*.html"))).select do |f|
    read_utf8(f).match?(/href="[^"]*cv-minozzi-[^"]*\.pdf"/)
  end
  puts("      hardcoded in: #{offenders.map { |f| File.basename(f) }.join(', ')}") unless offenders.empty?
  offenders.empty?
end

check("both CV links route through site.cv_pdf") do
  [CVMD, File.join(ROOT, "_layouts", "default.html")].all? do |f|
    read_utf8(f).include?("site.cv_pdf")
  end
end

# Titles are matched on their first six words: the home page and publications
# page word subtitles slightly differently.
check("no published paper is still listed under Working Papers") do
  index = read_utf8(INDEX)
  working = index[/## Working Papers(.*?)(\n---|\z)/m, 1].to_s
  published_stems = entries.map do |e|
    e.lines.first.gsub(/\*\*/, "").strip.split(/\s+/).first(6).join(" ")
  end
  leaked = published_stems.select { |stem| working.include?(stem) }
  puts("      still listed as working: #{leaked.join(' | ')}") unless leaked.empty?
  leaked.empty?
end

puts
if $failures.empty?
  puts "All checks passed."
else
  puts "#{$failures.size} check(s) failed: #{$failures.join(', ')}"
  exit 1
end
