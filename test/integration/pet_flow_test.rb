require "test_helper"

# The public root IS the pet: no account needed. These tests walk the full
# app — adopt, care actions without a reload, the rescue path, and the care
# history log.
class PetFlowTest < ActionDispatch::IntegrationTest
  setup do
    @pet = Pet.current || Pet.create!(
      name: "Mochi",
      look: "mochi",
      active: true,
      base_hunger: 70,
      base_happiness: 72,
      base_energy: 68,
      last_cared_at: Time.current
    )
  end

  def care_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  test "the root renders the active pet with live stats and controls" do
    @pet.care_events.create!(action: "feed", message: "Mochi gobbles up the snack!", occurred_at: 1.hour.ago)
    @pet.care_events.create!(action: "play", message: "Mochi bounces with joy!", occurred_at: 2.hours.ago)

    get root_path

    assert_response :success
    assert_select "h1", text: /little companion/
    assert_select ".nano-pet[data-pet-look=mochi]"
    assert_select ".np-pet-name", text: "Mochi"
    assert_select "[data-np-stat=hunger]", text: "70"
    assert_select "[data-np-stat=happiness]", text: "72"
    assert_select "[data-np-stat=energy]", text: "68"
    assert_select "button", text: /Feed/
    assert_select "button", text: /Play/
    assert_select "button", text: /Rest/
    assert_select "#care-log .np-log__entry", minimum: 2
    assert_select ".np-log__action--feed"
    assert_select ".np-log__action--play"
  end

  test "feeding updates stats and the care log without a reload" do
    post feed_pet_path, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace]"
    assert_select "[data-np-stat=hunger]", text: "100"
    assert_select ".nano-pet--feed"
    assert_select ".np-log__action--feed", minimum: 1
  end

  test "playing raises happiness and costs energy" do
    post play_pet_path, as: :turbo_stream

    assert_response :success
    assert_select "[data-np-stat=happiness]", text: "100"
    assert_select "[data-np-stat=energy]", text: "56"
    assert_select ".nano-pet--play"
  end

  test "resting restores energy and shows the sleeping pet" do
    post rest_pet_path, as: :turbo_stream

    assert_response :success
    assert_select "[data-np-stat=energy]", text: "100"
    assert_select ".nano-pet--asleep"
  end

  test "a distressed pet offers the rescue path" do
    @pet.update!(base_hunger: 0, base_happiness: 0, base_energy: 0)

    get root_path
    assert_response :success
    assert_select ".np-rescue"

    post rescue_pet_path, as: :turbo_stream
    assert_response :success
    assert_select ".nano-pet--rescue"
    assert_select "[data-np-stat=hunger]", text: Pet::RESCUE_BOOST.to_s
    assert_select ".np-log__action--rescue", minimum: 1
  end

  test "a healthy pet has no rescue call-out" do
    get root_path
    assert_response :success
    assert_select ".np-rescue", count: 0
  end

  test "adopting a new pet makes it active and returns to the root" do
    get new_pet_path
    assert_response :success
    assert_select "form" do
      assert_select "input[name='pet[name]']"
      assert_select "input[name='pet[look]'][value=mochi]"
      assert_select "input[name='pet[look]'][value=blob]"
      assert_select "input[name='pet[look]'][value=gummy]"
    end

    post pet_path, params: { pet: { name: "Boba", look: "gummy" } }
    assert_redirected_to root_path
    follow_redirect!

    assert_select ".np-pet-name", text: "Boba"
    assert_not @pet.reload.active
    assert_equal "Boba", Pet.current.name
  end

  test "adoption name and look are validated" do
    post pet_path, params: { pet: { name: "", look: "unicorn" } }

    assert_response :unprocessable_content
  end
end
