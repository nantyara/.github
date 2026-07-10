require "rss"
require "open-uri"

module RadioReadme
  FEED_URL = "https://podcast.nantyara.com/feed.xml"
  README_PATH = File.expand_path("../profile/README.md", __dir__)
  MARKER_START = "<!-- radio:start -->"
  MARKER_END = "<!-- radio:end -->"
  EPISODE_COUNT = 3

  class FeedError < StandardError; end
  class MarkerError < StandardError; end

  module_function

  def build_section(feed_xml)
    feed = parse_feed(feed_xml)
    raise FeedError, "feed could not be parsed" if feed.nil?

    items = feed.items.first(EPISODE_COUNT)
    raise FeedError, "feed has no items" if items.empty?

    items.map do |item|
      if item.title.nil? || item.link.nil? || item.pubDate.nil?
        raise FeedError, "feed item is missing title/link/pubDate"
      end

      "- [#{item.title}](#{item.link}) (#{item.pubDate.strftime('%Y-%m-%d')})"
    end.join("\n")
  end

  def update(readme_content, feed_xml)
    unless readme_content.include?(MARKER_START) && readme_content.include?(MARKER_END)
      raise MarkerError, "README is missing #{MARKER_START} / #{MARKER_END} markers"
    end

    section = build_section(feed_xml)
    pattern = /#{Regexp.escape(MARKER_START)}.*?#{Regexp.escape(MARKER_END)}/m
    replacement = "#{MARKER_START}\n#{section}\n#{MARKER_END}"

    readme_content.sub(pattern, replacement)
  end

  def run(readme_path: README_PATH, feed_source: -> { URI.open(FEED_URL, open_timeout: 10, read_timeout: 10, &:read) })
    feed_xml = fetch_feed(feed_source)
    original = File.read(readme_path)
    updated = update(original, feed_xml)

    return false if updated == original

    File.write(readme_path, updated)
    true
  end

  def fetch_feed(feed_source)
    feed_source.call
  rescue FeedError
    raise
  rescue StandardError => e
    raise FeedError, e.message
  end

  def parse_feed(feed_xml)
    RSS::Parser.parse(feed_xml, false)
  rescue RSS::Error, RuntimeError, TypeError => e
    raise FeedError, e.message
  end
  private_class_method :parse_feed
end

if $PROGRAM_NAME == __FILE__
  begin
    RadioReadme.run
  rescue RadioReadme::FeedError, RadioReadme::MarkerError => e
    warn "update_readme failed: #{e.message}"
    exit 1
  end
end
