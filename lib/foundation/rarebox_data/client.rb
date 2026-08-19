# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Foundation
  module RareboxData
    # Reads catalog + prices from a local rarebox-data checkout or the
    # published GitHub raw / CDN URLs (CORS-open, no keys).
    class Client
      def initialize(game:, root: nil, remote: Foundation::RareboxData::DEFAULT_REMOTE)
        @game = game.to_s
        @root = resolve_root(root)
        @remote = remote.to_s.sub(%r{/\z}, "")
      end

      attr_reader :game, :root, :remote

      def sets
        read_json("catalog/#{@game}/sets.json")
      end

      def cards_for_set(set_id)
        read_json("catalog/#{@game}/sets/#{set_id}.json")
      end

      def latest_prices
        payload = read_json("prices/#{@game}/latest.json")
        {
          stamp: payload["stamp"] || payload["mirrored"],
          source: payload["source"],
          prices: payload["prices"] || {}
        }
      end

      def price_usd(rarebox_id, prices = nil)
        table = prices || latest_prices[:prices]
        value = table[rarebox_id.to_s]
        value.nil? ? nil : value.to_f
      end

      def status
        read_json("STATUS.json")
      rescue StandardError
        {}
      end

      private

      def resolve_root(explicit)
        candidates = [
          explicit,
          ENV["RAREBOX_DATA_PATH"],
          Rails.root.join("vendor/rarebox-data").to_s
        ].compact.map(&:to_s).reject(&:blank?)

        candidates.find { |path| File.directory?(path) }
      end

      def read_json(relative)
        if @root
          path = File.join(@root, relative)
          return JSON.parse(File.read(path)) if File.file?(path)
        end

        uri = URI.parse("#{@remote}/#{relative}")
        response = Net::HTTP.get_response(uri)
        raise "rarebox-data fetch failed #{uri} (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end
  end
end
