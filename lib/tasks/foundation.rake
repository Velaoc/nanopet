# frozen_string_literal: true

namespace :foundation do
  desc "Regenerate public icon SVG/PNGs from brand_seed_color in config/foundation.yml"
  task icon: :environment do
    seed = Rails.configuration.x.foundation[:brand_seed_color]
    written = Foundation::AppIcon.write_all!(seed)

    puts "Wrote #{written.join(', ')} from brand_seed_color #{Foundation::AppIcon.normalize_color(seed)}."
  end
end
