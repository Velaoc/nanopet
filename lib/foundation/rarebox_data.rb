# frozen_string_literal: true

require_relative "rarebox_data/client"
require_relative "rarebox_data/catalog_import"

module Foundation
  # Integration with the public CC0 TCG dataset novaoc/rarebox-data.
  # Any generated app that tracks TCG catalog or market marks should use
  # this client rather than inventing a private price source.
  #
  #   rarebox_data:
  #     enabled: true
  #     game: pokemon
  #     path: ""   # optional local checkout; else GitHub raw / jsDelivr
  #
  # See docs/RAREBOX_DATA.md.
  module RareboxData
    DEFAULT_REMOTE = "https://raw.githubusercontent.com/novaoc/rarebox-data/main"
    GAMES = %w[pokemon pokemon-ja mtg yugioh lorcana one-piece riftbound].freeze

    module_function

    def enabled?
      config[:enabled] == true
    end

    def config
      raw = Rails.configuration.x.foundation[:rarebox_data]
      raw = {} unless raw.is_a?(Hash)
      raw.with_indifferent_access
    end

    def game
      value = config[:game].presence || "pokemon"
      value = value.to_s
      raise ArgumentError, "unsupported rarebox game #{value.inspect}" unless GAMES.include?(value)

      value
    end

    def client
      Client.new(
        game: game,
        root: config[:path].presence,
        remote: config[:remote].presence || DEFAULT_REMOTE
      )
    end
  end
end
