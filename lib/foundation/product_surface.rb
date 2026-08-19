# frozen_string_literal: true

module Foundation
  # Product surface — which foundation chrome a generated app exposes.
  #
  # Modules decide what code is on disk (docs/MODULES.md). The product surface
  # decides what a signed-in person is offered in navigation and public chrome
  # for *this* product. A commerce app must not look like an operator console
  # just because organizations and billing exist underneath.
  #
  # Configure in config/foundation.yml:
  #
  #   product_surface: commerce
  #
  # Optional per-feature overrides (boolean only):
  #
  #   product_surface_features:
  #     billing: true
  #
  # See docs/PRODUCT_SURFACE.md.
  class ProductSurface
    class Invalid < StandardError; end

    FEATURES = %i[
      home
      shop
      cart
      account
      organizations
      connections
      devices
      billing
      pricing
      crm
      admin
    ].freeze

    # Profiles are the supported product contexts. `platform` preserves the
    # historical full shell so an unstamped foundation checkout behaves as
    # before. Other profiles hide foundation plumbing that does not belong
    # in that product's primary UI.
    PROFILES = {
      "platform" => {
        home: true,
        shop: :storefront,
        cart: :storefront,
        account: false,
        organizations: true,
        connections: true,
        devices: true,
        billing: :without_storefront,
        pricing: :public_without_storefront,
        crm: :module_crm,
        admin: :operator
      }.freeze,
      "commerce" => {
        home: false,
        shop: true,
        cart: true,
        account: true,
        organizations: false,
        connections: false,
        devices: false,
        billing: false,
        pricing: false,
        crm: false,
        admin: :operator
      }.freeze,
      "workspace" => {
        home: true,
        shop: false,
        cart: false,
        account: false,
        organizations: true,
        connections: true,
        devices: true,
        billing: true,
        pricing: true,
        crm: :module_crm,
        admin: :operator
      }.freeze,
      "consumer" => {
        home: true,
        shop: false,
        cart: false,
        account: true,
        organizations: false,
        connections: false,
        devices: false,
        billing: false,
        pricing: false,
        crm: false,
        admin: :operator
      }.freeze
    }.freeze

    attr_reader :name, :features

    def self.profiles
      PROFILES.keys.freeze
    end

    def self.resolve(foundation_config)
      raw = foundation_config.is_a?(Hash) ? foundation_config : {}
      name = raw[:product_surface].presence || raw["product_surface"].presence || "platform"
      name = name.to_s
      raise Invalid, "unknown product_surface #{name.inspect}; expected one of #{profiles.join(", ")}" unless PROFILES.key?(name)

      overrides = raw[:product_surface_features] || raw["product_surface_features"] || {}
      overrides = overrides.to_h if overrides.respond_to?(:to_h)
      new(name, overrides)
    end

    def initialize(name, overrides = {})
      @name = name.to_s
      base = PROFILES.fetch(@name).dup
      overrides.each do |key, value|
        feature = key.to_sym
        next unless FEATURES.include?(feature)
        next if value.nil?

        base[feature] = ActiveModel::Type::Boolean.new.cast(value)
      end
      @features = base.freeze
    end

    def feature?(name, operator: false)
      decision = @features.fetch(name.to_sym) { false }
      case decision
      when true then true
      when false then false
      # After storefront omit the block above is stripped; absent storefront
      # means "without storefront" features are available.
      when :without_storefront, :public_without_storefront
        true
      when :operator
        operator == true
      else
        false
      end
    end

    def profile?(candidate)
      name == candidate.to_s
    end
  end

  def self.product_surface
    ProductSurface.resolve(Rails.configuration.x.foundation)
  end

  def self.surface_feature?(name, operator: false)
    product_surface.feature?(name, operator: operator)
  end
end
