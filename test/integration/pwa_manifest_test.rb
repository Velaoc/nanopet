require "test_helper"
require "json"

# SPEC M10.2: the manifest is public, describes the configured product, and
# is linked from the pages an installable application is reached through.
class PwaManifestTest < ActionDispatch::IntegrationTest
  test "the manifest is public and rendered from config/foundation.yml" do
    identity = Rails.configuration.x.foundation
    surface = JSON.parse(Rails.root.join("config/material_tokens.json").read).dig("schemes", "light", "surface")

    get pwa_manifest_path

    assert_response :success
    assert_equal "application/manifest+json", response.media_type

    payload = JSON.parse(response.body)
    assert_equal identity[:application_name], payload.fetch("name")
    assert_equal identity[:default_page_description], payload.fetch("description")
    assert_equal Foundation::AppIcon.normalize_color(identity[:brand_seed_color]), payload.fetch("theme_color")
    assert_equal Foundation::AppIcon.normalize_color(surface), payload.fetch("background_color")

    icons = payload.fetch("icons")
    assert icons.any? { |icon| icon["src"] == "/icon-192.png" && icon["sizes"] == "192x192" && icon["type"] == "image/png" }
    assert icons.any? { |icon| icon["src"] == "/icon-512.png" && icon["sizes"] == "512x512" && icon["purpose"] == "any" }
    assert icons.any? { |icon| icon["src"] == "/icon-512.png" && icon["purpose"] == "maskable" }
    assert icons.any? { |icon| icon["src"] == "/icon.svg" && icon["type"] == "image/svg+xml" }
  end

  test "public pages link the manifest, icons, and install metadata" do
    get root_path

    assert_response :success
    assert_select "meta[name=viewport][content=?]", "width=device-width,initial-scale=1,viewport-fit=cover"
    assert_select "meta[name=apple-mobile-web-app-capable][content=yes]"
    assert_select "meta[name=apple-mobile-web-app-status-bar-style][content=black-translucent]"
    assert_select "meta[name=mobile-web-app-capable][content=yes]"
    assert_select "link[rel=manifest][href=?]", pwa_manifest_path
    assert_select "link[rel=icon][href='/icon.svg'][type='image/svg+xml']"
    assert_select "link[rel=apple-touch-icon][href='/apple-touch-icon.png'][sizes=?]", "180x180"
  end

  test "apple-touch-icon is served as a real 180x180 PNG" do
    get "/apple-touch-icon.png"

    assert_response :success
    assert_includes response.media_type, "image/png"
    width, height = Foundation::AppIcon.png_dimensions(response.body)
    assert_equal [ 180, 180 ], [ width, height ]
    assert_equal Foundation::AppIcon.png(180, Rails.configuration.x.foundation[:brand_seed_color]), response.body.b
  end

  test "manifest PNG icons are served at the declared sizes" do
    {
      "/icon-192.png" => 192,
      "/icon-512.png" => 512
    }.each do |path, dimension|
      get path
      assert_response :success, path
      assert_includes response.media_type, "image/png"
      assert_equal [ dimension, dimension ], Foundation::AppIcon.png_dimensions(response.body)
    end
  end

  test "no service worker is registered" do
    get root_path

    assert_response :success
    assert_no_match(/serviceWorker/, response.body)

    get "/service-worker"
    assert_response :not_found
  end
end
