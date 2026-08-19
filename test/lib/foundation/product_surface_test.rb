# frozen_string_literal: true

require "test_helper"

class Foundation::ProductSurfaceTest < ActiveSupport::TestCase
  test "platform keeps organizations chrome" do
    surface = Foundation::ProductSurface.new("platform")
    assert surface.feature?(:organizations)
    assert surface.feature?(:devices)
    assert_not surface.feature?(:admin, operator: false)
    assert surface.feature?(:admin, operator: true)
  end

  test "commerce hides foundation plumbing" do
    surface = Foundation::ProductSurface.new("commerce")
    assert surface.feature?(:shop)
    assert surface.feature?(:cart)
    assert surface.feature?(:account)
    assert_not surface.feature?(:organizations)
    assert_not surface.feature?(:connections)
    assert_not surface.feature?(:billing)
  end

  test "workspace enables org and billing chrome" do
    surface = Foundation::ProductSurface.new("workspace")
    assert surface.feature?(:organizations)
    assert surface.feature?(:billing)
    assert surface.feature?(:home)
    assert_not surface.feature?(:shop)
  end

  test "unknown profile raises" do
    assert_raises Foundation::ProductSurface::Invalid do
      Foundation::ProductSurface.resolve(product_surface: "boutique")
    end
  end

  test "boolean overrides apply" do
    surface = Foundation::ProductSurface.new("commerce", { "billing" => true })
    assert surface.feature?(:billing)
  end

  test "default config resolves platform" do
    assert_equal "platform", Foundation.product_surface.name
  end
end
