require "test_helper"
require "json"

# SPEC M10.2: the web app manifest carries no identity of its own. Everything
# it publishes — name, description, and colors — has to follow
# config/foundation.yml (and the MD3 surface token) so bin/rename is enough
# to rebrand an installed app.
class WebManifestTest < ActiveSupport::TestCase
  IDENTITY = {
    application_name: "Acme Shop",
    default_page_description: "Licenses for the Acme toolchain",
    brand_seed_color: "#b3261e"
  }.with_indifferent_access

  def manifest(overrides = {})
    Foundation::WebManifest.new(IDENTITY.merge(overrides)).as_json
  end

  def light_surface
    JSON.parse(Rails.root.join("config/material_tokens.json").read).dig("schemes", "light", "surface")
  end

  test "identity and colors come from configuration" do
    payload = manifest

    assert_equal "Acme Shop", payload.fetch("name")
    assert_equal "Licenses for the Acme toolchain", payload.fetch("description")
    assert_equal "#B3261E", payload.fetch("theme_color")
    assert_equal Foundation::AppIcon.normalize_color(light_surface), payload.fetch("background_color")
    assert_not_equal payload.fetch("theme_color"), payload.fetch("background_color")
    assert_equal "/", payload.fetch("start_url")
    assert_equal "/", payload.fetch("scope")
    assert_equal "standalone", payload.fetch("display")
  end

  test "icons include PNG 192, 512, maskable, and the regenerable SVG" do
    icons = manifest.fetch("icons")

    png_192 = icons.find { |icon| icon["src"] == "/icon-192.png" }
    png_512_any = icons.find { |icon| icon["src"] == "/icon-512.png" && icon["purpose"] == "any" }
    png_512_maskable = icons.find { |icon| icon["src"] == "/icon-512.png" && icon["purpose"] == "maskable" }
    svg = icons.find { |icon| icon["src"] == "/icon.svg" }

    assert_equal "192x192", png_192.fetch("sizes")
    assert_equal "image/png", png_192.fetch("type")
    assert_equal "any", png_192.fetch("purpose")

    assert_equal "512x512", png_512_any.fetch("sizes")
    assert_equal "image/png", png_512_any.fetch("type")

    assert_equal "512x512", png_512_maskable.fetch("sizes")
    assert_equal "image/png", png_512_maskable.fetch("type")
    assert_equal "maskable", png_512_maskable.fetch("purpose")

    assert_equal "image/svg+xml", svg.fetch("type")
    assert_equal "any", svg.fetch("sizes")
  end

  test "the short name is truncated on a word boundary" do
    assert_equal "Acme Shop", manifest.fetch("short_name")
    assert_equal "Acme", manifest(application_name: "Acme Toolchain Licensing").fetch("short_name")
    assert_equal "Supercalifra", manifest(application_name: "Supercalifragilistic").fetch("short_name")
  end

  test "a blank product name falls back instead of publishing an empty label" do
    assert_equal "Application", manifest(application_name: "  ").fetch("name")
  end

  test "an unusable seed color is refused rather than silently themed" do
    assert_raises(Foundation::AppIcon::InvalidColor) { manifest(brand_seed_color: "rebeccapurple") }
  end
end
