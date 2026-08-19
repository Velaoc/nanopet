# frozen_string_literal: true

namespace :rarebox do
  desc "Show rarebox-data configuration and STATUS.json summary"
  task status: :environment do
    cfg = Foundation::RareboxData.config
    puts "enabled=#{Foundation::RareboxData.enabled?} game=#{cfg[:game]} path=#{cfg[:path].inspect}"
    client = Foundation::RareboxData.client
    puts "root=#{client.root.inspect} remote=#{client.remote}"
    status = client.status
    puts JSON.pretty_generate(status) if status.present?
    prices = client.latest_prices
    puts "prices_stamp=#{prices[:stamp]} count=#{prices[:prices].size}"
  end

  desc "Print sample normalized cards for SET (default base1)"
  task :sample_cards, [ :set_id ] => :environment do |_t, args|
    set_id = args[:set_id].presence || "base1"
    Foundation::RareboxData::CatalogImport.new(set_ids: [ set_id ], limit_per_set: 5).each_card do |attrs|
      puts attrs.slice(:rarebox_id, :name, :set_name, :market_price_usd, :image_url).inspect
    end
  end
end
