# frozen_string_literal: true

require "test_helper"

class Foundation::DesignSkinTest < ActiveSupport::TestCase
  test "default config resolves material" do
    assert_equal "material", Foundation.design_skin.name
    assert_equal "design-skin--material", Foundation.design_skin.body_class
  end

  test "surface pairing picks commerce skin" do
    skin = Foundation::DesignSkin.resolve(product_surface: "commerce")
    assert_equal "commerce", skin.name
  end

  test "explicit skin wins over surface pairing" do
    skin = Foundation::DesignSkin.resolve(product_surface: "commerce", design_skin: "vault")
    assert_equal "vault", skin.name
  end

  test "unknown skin raises" do
    assert_raises Foundation::DesignSkin::Invalid do
      Foundation::DesignSkin.resolve(design_skin: "neon-dream")
    end
  end

  test "every named skin is documented in css" do
    css = Rails.root.join("app/assets/stylesheets/design_skins.css").read
    Foundation::DesignSkin.names.each do |name|
      next if name == "material"

      assert_includes css, ".design-skin--#{name}", "expected CSS hooks for #{name}"
    end
  end
end
