# frozen_string_literal: true

require "json"

module Foundation
  # Web application manifest built from the product identity (SPEC M10.2).
  #
  # Nothing here is hardcoded: name, description, theme color, and icons come
  # from config/foundation.yml (and the MD3 surface token derived from the
  # brand seed), so stamping an identity with bin/rename (or editing that file)
  # updates the installed application's name, splash screen, and theme without
  # touching this class.
  class WebManifest
    SHORT_NAME_LIMIT = 12
    TOKENS_PATH = "config/material_tokens.json"

    def initialize(identity)
      @identity = identity
    end

    def as_json(*)
      {
        "id" => "/",
        "name" => application_name,
        "short_name" => short_name,
        "description" => description,
        "start_url" => "/",
        "scope" => "/",
        "display" => "standalone",
        "theme_color" => theme_color,
        "background_color" => background_color,
        "icons" => icons
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end

    def theme_color
      AppIcon.normalize_color(@identity[:brand_seed_color])
    end

    # Launch / splash background. Uses the light MD3 surface (not the brand
    # seed) so the splash reads as the app canvas rather than a solid brand
    # block while the first paint loads.
    def background_color
      surface = light_surface_token
      return AppIcon.normalize_color(surface) if surface.present?

      "#FFFFFF"
    end

    private

    def application_name
      @identity[:application_name].to_s.strip.presence || "Application"
    end

    def description
      @identity[:default_page_description].to_s.strip
    end

    # Home-screen labels are truncated by the launcher anyway; cut on a word
    # boundary so the short name stays readable and deterministic.
    def short_name
      return application_name if application_name.length <= SHORT_NAME_LIMIT

      truncated = application_name[0, SHORT_NAME_LIMIT]
      truncated = truncated[0, truncated.rindex(" ")] if truncated.include?(" ")
      truncated.strip
    end

    def icons
      [
        { "src" => "/icon-192.png", "type" => "image/png", "sizes" => "192x192", "purpose" => "any" },
        { "src" => "/icon-512.png", "type" => "image/png", "sizes" => "512x512", "purpose" => "any" },
        { "src" => "/icon-512.png", "type" => "image/png", "sizes" => "512x512", "purpose" => "maskable" },
        { "src" => "/icon.svg", "type" => "image/svg+xml", "sizes" => "any", "purpose" => "any" }
      ]
    end

    def light_surface_token
      path = Rails.root.join(TOKENS_PATH)
      return nil unless path.exist?

      JSON.parse(path.read).dig("schemes", "light", "surface")
    rescue JSON::ParserError
      nil
    end
  end
end
