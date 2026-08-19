# frozen_string_literal: true

module Foundation
  module RareboxData
    # Maps rarebox-data card JSON into a plain Hash ready for app models.
    # Generated apps own their AR schema; the foundation only normalizes
    # the public dataset shape.
    #
    #   Foundation::RareboxData::CatalogImport.new(set_ids: %w[base1 sv3]).each_card { |attrs| ... }
    class CatalogImport
      DEFAULT_SET_IDS = %w[base1 base2 sv1 sv3].freeze

      def initialize(client: nil, set_ids: DEFAULT_SET_IDS, limit_per_set: 50)
        @client = client || Foundation::RareboxData.client
        @set_ids = Array(set_ids)
        @limit_per_set = limit_per_set
      end

      def latest_stamp
        @client.latest_prices[:stamp]
      end

      def each_card
        return enum_for(:each_card) unless block_given?

        prices = @client.latest_prices[:prices]
        @set_ids.each do |set_id|
          cards = Array(@client.cards_for_set(set_id))
          ranked = cards.sort_by { |card| [ -prices[card["id"].to_s].to_f, card["number"].to_s ] }
          ranked.first(@limit_per_set).each do |card|
            rid = card["id"].to_s
            next if rid.blank?

            usd = prices[rid]
            yield({
              rarebox_id: rid,
              name: card["name"].to_s,
              number: card["number"].to_s,
              rarity: card["rarity"].presence || "Unknown",
              set_id: card.dig("set", "id").presence || set_id,
              set_name: card.dig("set", "name").presence || set_id,
              image_url: card["image"],
              supertype: card["supertype"],
              game: card["game"].presence || @client.game,
              market_price_cents: usd.nil? ? nil : (usd.to_f * 100).round,
              market_price_usd: usd.nil? ? nil : usd.to_f
            })
          end
        rescue StandardError => error
          Rails.logger.warn("[RareboxData::CatalogImport] #{set_id}: #{error.class}: #{error.message}")
        end
      end
    end
  end
end
