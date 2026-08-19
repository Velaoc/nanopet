# Rarebox Data (TCG)

**Rule:** any foundation-built app that shows TCG catalog rows or market
prices must use [novaoc/rarebox-data](https://github.com/novaoc/rarebox-data)
— the public CC0 dataset — not a private scrape or hard-coded fantasy marks.

Full consumer docs: [docs.rarebox.io/data/rarebox-data](https://docs.rarebox.io/data/rarebox-data).

## Configure

```yaml
rarebox_data:
  enabled: true
  game: pokemon          # pokemon | pokemon-ja | mtg | yugioh | lorcana | one-piece | riftbound
  path: ""               # optional local checkout; else GitHub raw
  remote: "https://raw.githubusercontent.com/novaoc/rarebox-data/main"
```

Environment override for local checkouts:

```bash
export RAREBOX_DATA_PATH=/path/to/rarebox-data
```

## API

```ruby
client = Foundation::RareboxData.client
client.sets
client.cards_for_set("base1")
client.latest_prices
# => { stamp: "...", prices: { "base1-4" => 818.65, ... } }

Foundation::RareboxData::CatalogImport.new(set_ids: %w[base1 sv3]).each_card do |attrs|
  # attrs: rarebox_id, name, set_id, set_name, number, rarity,
  #        image_url, market_price_cents, market_price_usd, game, …
end
```

Rake (when enabled):

```bash
bin/rails rarebox:status
bin/rails rarebox:sample_cards[base1]
```

## App responsibilities

The foundation ships the **client and normalizer only**. Generated apps own:

- ActiveRecord schema (`rarebox_id`, marks, holdings, …)
- Sync jobs / seeds that call `CatalogImport`
- Image rendering (URLs point at upstream hosts; binaries are not stored)
- Caching (files change at most daily)

## Price keys

`${setId}-${normalizedNumber}` — lowercase, strip `/total` and leading zeros.
`$0` is a valid market price; unknown cards are **absent**, never `null`.

## Licensing

Dataset: **CC0 1.0**. Card image binaries are not part of the dataset; image
URLs remain © their hosts.
