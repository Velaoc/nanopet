# frozen_string_literal: true

module Foundation
  # Design skin — product-context visual language layered on MD3 tokens.
  #
  # Modules and product_surface decide *what* ships and *which chrome* shows.
  # The design skin decides *how* the shell looks for this product family.
  # Skins remap MD3 CSS variables and shell geometry; they do not replace
  # Material components or invent a second component library.
  #
  #   design_skin: commerce   # material | commerce | workspace | arcade | vault | signal
  #
  # See docs/DESIGN_SKINS.md.
  class DesignSkin
    class Invalid < StandardError; end

    # Conceptual families (not product brands). Each maps to a CSS body class
    # `design-skin--{name}` and optional stylesheet hooks.
    SKINS = {
      "material" => {
        summary: "Default Material Design 3 shell from brand_seed_color",
        color_scheme: "system",
        body_class: "design-skin--material"
      }.freeze,
      "commerce" => {
        summary: "Dark precision storefront — grid, glass panels, luminous CTAs",
        color_scheme: "dark",
        body_class: "design-skin--commerce"
      }.freeze,
      "workspace" => {
        summary: "Operations console — dense navy deck, cyan signals, data chrome",
        color_scheme: "dark",
        body_class: "design-skin--workspace"
      }.freeze,
      "arcade" => {
        summary: "Entertainment HUD — deep void, neon edges, telemetry type",
        color_scheme: "dark",
        body_class: "design-skin--arcade"
      }.freeze,
      "vault" => {
        summary: "Holdings terminal — charcoal vault, bullion marks, tabular finance",
        color_scheme: "dark",
        body_class: "design-skin--vault"
      }.freeze,
      "signal" => {
        summary: "Messaging OS — cool slate, teal accents, soft conversation geometry",
        color_scheme: "dark",
        body_class: "design-skin--signal"
      }.freeze
    }.freeze

    # Suggested pairing when an operator only sets product_surface.
    SURFACE_DEFAULT_SKIN = {
      "platform" => "material",
      "commerce" => "commerce",
      "workspace" => "workspace",
      "consumer" => "signal"
    }.freeze

    attr_reader :name, :summary, :color_scheme, :body_class

    def self.names
      SKINS.keys.freeze
    end

    def self.resolve(foundation_config)
      raw = foundation_config.is_a?(Hash) ? foundation_config : {}
      explicit = raw[:design_skin].presence || raw["design_skin"].presence
      surface = raw[:product_surface].presence || raw["product_surface"].presence || "platform"
      name = (explicit.presence || SURFACE_DEFAULT_SKIN[surface.to_s] || "material").to_s
      raise Invalid, "unknown design_skin #{name.inspect}; expected one of #{names.join(", ")}" unless SKINS.key?(name)

      new(name)
    end

    def initialize(name)
      @name = name.to_s
      meta = SKINS.fetch(@name)
      @summary = meta.fetch(:summary)
      @color_scheme = meta.fetch(:color_scheme)
      @body_class = meta.fetch(:body_class)
    end

    def material?
      name == "material"
    end
  end

  def self.design_skin
    DesignSkin.resolve(Rails.configuration.x.foundation)
  end
end
