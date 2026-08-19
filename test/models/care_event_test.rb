require "test_helper"

# Every care action must be recorded with its timestamp and a pet must be
# able to log a full history.
class CareEventTest < ActiveSupport::TestCase
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

  test "belongs to a pet" do
    event = @pet.care_events.create!(action: "feed", message: "Yum!", occurred_at: Time.current)

    assert_equal @pet, event.pet
  end

  test "rejects an unknown action" do
    event = @pet.care_events.build(action: "dance", occurred_at: Time.current)

    assert_not event.valid?
    assert_includes event.errors[:action], "is not included in the list"
  end

  test "records the timestamp of the care action" do
    moment = Time.utc(2026, 8, 11, 12, 0, 0)
    event = @pet.care_events.create!(action: "play", message: "Whee!", occurred_at: moment)

    assert_equal moment, event.occurred_at
  end

  test "care events are listed newest first" do
    @pet.care_events.create!(action: "feed", message: "First", occurred_at: 2.hours.ago)
    @pet.care_events.create!(action: "play", message: "Second", occurred_at: 1.hour.ago)

    assert_equal %w[Second First], @pet.care_events.map(&:message)
  end
end
