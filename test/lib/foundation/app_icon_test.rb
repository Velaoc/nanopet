require "test_helper"

# SPEC M10.2: the shipped icon is a placeholder derived from the brand seed
# color, and it must stay derivable — every committed mark regenerates from
# configuration.
class AppIconTest < ActiveSupport::TestCase
  ICON = Rails.root.join(Foundation::AppIcon::PATH)
  SEED = Rails.configuration.x.foundation[:brand_seed_color]

  test "the committed icon matches the configured brand seed" do
    assert_predicate ICON, :exist?
    assert_equal Foundation::AppIcon.svg(SEED), ICON.read,
      "public/icon.svg is stale; run bin/rails foundation:icon after changing brand_seed_color"
  end

  test "committed PNG icons match the configured brand seed and sizes" do
    Foundation::AppIcon::PNG_PATHS.each do |dimension, relative|
      path = Rails.root.join(relative)
      assert_predicate path, :exist?, "#{relative} is missing; run bin/rails foundation:icon"
      bytes = path.binread
      assert_equal Foundation::AppIcon.png(dimension, SEED), bytes,
        "#{relative} is stale; run bin/rails foundation:icon after changing brand_seed_color"
      width, height = Foundation::AppIcon.png_dimensions(bytes)
      assert_equal [ dimension, dimension ], [ width, height ], "#{relative} must be #{dimension}x#{dimension}"
    end
  end

  test "the artwork is square and stays inside the maskable safe zone" do
    svg = Foundation::AppIcon.svg("#6750A4")

    assert_includes svg, %(viewBox="0 0 512 512")
    assert_includes svg, %(<rect width="512" height="512" fill="#6750A4"/>)
    assert_operator Foundation::AppIcon::OUTER_RADIUS, :<=, Foundation::AppIcon::SAFE_RADIUS
    assert_operator Foundation::AppIcon::INNER_RADIUS, :<, Foundation::AppIcon::OUTER_RADIUS
  end

  test "generation is deterministic and depends only on the seed" do
    assert_equal Foundation::AppIcon.svg("#6750A4"), Foundation::AppIcon.svg("6750a4")
    assert_not_equal Foundation::AppIcon.svg("#6750A4"), Foundation::AppIcon.svg("#B3261E")
    assert_equal Foundation::AppIcon.png(32, "#6750A4"), Foundation::AppIcon.png(32, "6750a4")
    assert_not_equal Foundation::AppIcon.png(32, "#6750A4"), Foundation::AppIcon.png(32, "#B3261E")
  end

  test "PNG output is a real PNG of the requested size" do
    bytes = Foundation::AppIcon.png(180, "#6750A4")

    assert bytes.start_with?(Foundation::AppIcon::PNG_SIGNATURE)
    assert_equal [ 180, 180 ], Foundation::AppIcon.png_dimensions(bytes)
  end

  test "the mark contrasts with any seed color" do
    assert_equal "#FFFFFF", Foundation::AppIcon.foreground_for("#000000")
    assert_equal "#000000", Foundation::AppIcon.foreground_for("#FFFFFF")
    assert_equal "#000000", Foundation::AppIcon.foreground_for("#FFD400")
    assert_equal "#FFFFFF", Foundation::AppIcon.foreground_for("#6750A4")
  end

  test "an unusable seed color is refused rather than guessed" do
    [ "", "purple", "#12345", "#12345g", "#6750A4A4", "rgb(1,2,3)", nil ].each do |value|
      assert_raises(Foundation::AppIcon::InvalidColor, "expected #{value.inspect} to be refused") do
        Foundation::AppIcon.svg(value)
      end
      assert_raises(Foundation::AppIcon::InvalidColor, "expected #{value.inspect} to be refused as PNG") do
        Foundation::AppIcon.png(64, value)
      end
    end
  end
end
