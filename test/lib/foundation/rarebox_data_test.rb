# frozen_string_literal: true

require "test_helper"

class Foundation::RareboxDataTest < ActiveSupport::TestCase
  test "disabled by default" do
    assert_not Foundation::RareboxData.enabled?
  end

  test "client reads local rarebox-data when path exists" do
    path = [
      ENV["RAREBOX_DATA_PATH"],
      "/Users/wren/nova/rarebox-data",
      Rails.root.join("vendor/rarebox-data").to_s
    ].compact.find { |p| File.directory?(p) }

    skip "rarebox-data checkout not present" unless path

    client = Foundation::RareboxData::Client.new(game: "pokemon", root: path)
    sets = client.sets
    assert sets.is_a?(Array) || sets.is_a?(Hash)
    prices = client.latest_prices
    assert prices[:prices].is_a?(Hash)
    assert prices[:prices].any?, "expected non-empty pokemon price table"
  end

  test "catalog import yields normalized attrs from local data" do
    path = [
      ENV["RAREBOX_DATA_PATH"],
      "/Users/wren/nova/rarebox-data"
    ].compact.find { |p| File.directory?(p) }

    skip "rarebox-data checkout not present" unless path

    client = Foundation::RareboxData::Client.new(game: "pokemon", root: path)
    cards = Foundation::RareboxData::CatalogImport.new(client: client, set_ids: %w[base1], limit_per_set: 3).each_card.to_a
    assert_operator cards.size, :>, 0
    card = cards.first
    assert card[:rarebox_id].present?
    assert card[:name].present?
    assert card[:set_id].present?
    assert card.key?(:market_price_cents)
  end

  test "unsupported game raises" do
    original = Rails.configuration.x.foundation[:rarebox_data]
    Rails.configuration.x.foundation[:rarebox_data] = { enabled: true, game: "digimon" }
    assert_raises(ArgumentError) { Foundation::RareboxData.game }
  ensure
    Rails.configuration.x.foundation[:rarebox_data] = original
  end
end
