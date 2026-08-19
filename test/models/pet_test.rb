require "test_helper"

# The pet's core promise: stats are derived from base values plus real
# elapsed time, computed at read time — never decremented by a job. These
# tests pin the decay math and every care action's effect.
class PetTest < ActiveSupport::TestCase
  setup do
    @pet = Pet.create!(
      name: "Mochi",
      look: "mochi",
      active: true,
      base_hunger: 70,
      base_happiness: 72,
      base_energy: 68,
      last_cared_at: Time.current
    )
  end

  test "fresh pet stats match the stored bases" do
    stats = @pet.stats

    assert_equal 70, stats[:hunger]
    assert_equal 72, stats[:happiness]
    assert_equal 68, stats[:energy]
  end

  test "hunger rises and happiness and energy fall with elapsed time" do
    later = 1.hour.from_now
    stats = @pet.stats(at: later)

    assert_operator stats[:hunger], :>, 70
    assert_operator stats[:happiness], :<, 72
    assert_operator stats[:energy], :<, 68
  end

  test "decay scales linearly with elapsed hours" do
    one_hour = @pet.stats(at: 1.hour.from_now)
    two_hours = @pet.stats(at: 2.hours.from_now)

    # Hunger rises 8/hour, happiness falls 6/hour, energy falls 5/hour.
    assert_equal 78, one_hour[:hunger]
    assert_equal 66, one_hour[:happiness]
    assert_equal 63, one_hour[:energy]

    assert_equal 86, two_hours[:hunger]
    assert_equal 60, two_hours[:happiness]
    assert_equal 58, two_hours[:energy]
  end

  test "stats clamp at 0 and 100 no matter how much time passes" do
    stats = @pet.stats(at: 10.days.from_now)

    assert_equal 100, stats[:hunger]
    assert_equal 0, stats[:happiness]
    assert_equal 0, stats[:energy]
  end

  test "no decay before the last care event" do
    past = @pet.last_cared_at - 2.hours

    stats = @pet.stats(at: past)

    assert_equal 70, stats[:hunger]
    assert_equal 72, stats[:happiness]
    assert_equal 68, stats[:energy]
  end

  test "feeding raises hunger immediately and logs a care event" do
    assert_difference -> { @pet.care_events.count }, 1 do
      @pet.feed!
    end

    assert_equal 100, @pet.hunger
    assert_equal "feed", @pet.care_events.first.action
    assert_match(/full and happy/, @pet.care_events.first.message)
  end

  test "feeding caps hunger at 100" do
    @pet.feed!
    @pet.feed!
    @pet.feed!

    assert_equal 100, @pet.hunger
  end

  test "playing raises happiness and costs a little energy" do
    @pet.play!

    assert_equal 100, @pet.happiness
    assert_equal 56, @pet.energy
    assert_equal "play", @pet.care_events.first.action
  end

  test "playing never drives energy below zero" do
    6.times { @pet.play! }

    assert_operator @pet.energy, :>=, 0
  end

  test "rest restores energy and pauses hunger for the rest window" do
    @pet.rest!

    assert_equal 100, @pet.energy
    assert @pet.resting?
    assert_equal Pet::REST_MINUTES.minutes.to_i, (@pet.resting_until - @pet.last_cared_at).to_i

    # Fifteen minutes into the rest: no hunger decay yet.
    fifteen_minutes_in = @pet.last_cared_at + 15.minutes
    assert_equal @pet.base_hunger, @pet.hunger(at: fifteen_minutes_in)
    assert_equal @pet.base_energy, @pet.energy(at: fifteen_minutes_in)
  end

  test "rest pauses hunger only until the rest window ends" do
    @pet.rest!

    after_rest = @pet.last_cared_at + Pet::REST_MINUTES.minutes + 30.minutes
    stats = @pet.stats(at: after_rest)

    assert_operator stats[:hunger], :>, @pet.base_hunger
  end

  test "a pet with a bottomed-out stat is distressed" do
    @pet.update!(base_happiness: 0)

    assert @pet.distressed?
  end

  test "rescue comforts a neglected pet back to stable stats" do
    @pet.update!(base_hunger: 0, base_happiness: 0, base_energy: 0)
    assert @pet.distressed?

    assert_difference -> { @pet.care_events.count }, 1 do
      @pet.rescue!
    end

    assert_equal Pet::RESCUE_BOOST, @pet.hunger
    assert_equal Pet::RESCUE_BOOST, @pet.happiness
    assert_equal Pet::RESCUE_BOOST, @pet.energy
    assert_not @pet.distressed?
    assert_equal "rescue", @pet.care_events.first.action
  end

  test "care actions fold accumulated decay into the stored bases" do
    @pet.update!(last_cared_at: 2.hours.ago)

    @pet.feed!

    # 2h of decay had pushed hunger to 86 and happiness to 60; feeding then
    # adds 35 on top of the decayed start (capped at 100), and the stored
    # bases now start from where the pet actually was.
    assert_equal 100, @pet.hunger
    assert_equal 100, @pet.base_hunger
    assert_equal 60, @pet.happiness
    assert_equal 60, @pet.base_happiness
  end

  test "only one pet is active at a time" do
    Pet.adopt!(name: "Blobby", look: "blob")

    assert_equal 1, Pet.active.count
    assert_equal "Blobby", Pet.current.name
    assert_not @pet.reload.active
  end

  test "adoption logs a welcome care event" do
    pet = Pet.adopt!(name: "Gummy", look: "gummy")

    assert_equal "adopt", pet.care_events.first.action
    assert_equal 75, pet.hunger
    assert_equal 80, pet.energy
  end

  test "stats accept a custom timestamp" do
    stats = @pet.stats(at: 90.minutes.from_now)

    assert_equal 82, stats[:hunger]
  end
end
