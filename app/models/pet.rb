# frozen_string_literal: true

# A virtual companion. Hunger/happiness/energy are not decremented by a
# background job: the Pet stores base values plus the timestamp of its last
# care event, and #stats derives the live values from real elapsed time
# whenever the pet is read.
class Pet < ApplicationRecord
  LOOKS = %w[mochi blob gummy].freeze
  ACTIONS = %w[feed play rest rescue adopt].freeze

  # Decay per real hour, in stat points.
  HUNGER_PER_HOUR = 8.0   # hunger rises as time passes
  HAPPINESS_PER_HOUR = 6.0
  ENERGY_PER_HOUR = 5.0

  # Effect of a single care action, in stat points.
  FEED_HUNGER = 35
  PLAY_HAPPINESS = 30
  PLAY_ENERGY_COST = 12
  REST_ENERGY = 40
  REST_MINUTES = 30
  RESCUE_BOOST = 55

  # Starting stats for a freshly adopted pet.
  ADOPT_HUNGER = 75
  ADOPT_HAPPINESS = 75
  ADOPT_ENERGY = 80

  has_many :care_events, -> { order(occurred_at: :desc) }, dependent: :destroy

  attribute :last_cared_at, default: -> { Time.current }

  validates :name, presence: true, length: { maximum: 40 }
  validates :look, inclusion: { in: LOOKS }
  validates :base_hunger, :base_happiness, :base_energy,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :active, -> { where(active: true) }

  # The pet the app opens onto. Exactly one pet is active at a time; a new
  # adoption deactivates the previous one.
  def self.current
    active.order(updated_at: :desc).first
  end

  # Adopt a brand-new pet: it becomes the single active pet and its welcome
  # is recorded as the first care event.
  def self.adopt!(name:, look: "mochi", at: Time.current)
    now = at.to_time
    transaction do
      where(active: true).update_all(active: false)
      pet = create!(
        name: name,
        look: look,
        active: true,
        base_hunger: ADOPT_HUNGER,
        base_happiness: ADOPT_HAPPINESS,
        base_energy: ADOPT_ENERGY,
        last_cared_at: now
      )
      pet.care_events.create!(action: "adopt", message: "Welcome home, #{name}!", occurred_at: now)
      pet
    end
  end

  # Live stats, derived from base values plus elapsed real time since the
  # last care event. Hunger rises; happiness and energy fall. Rested pets
  # pause decay until their rest window ends.
  def stats(at: Time.current)
    now = at.to_time
    elapsed = [ now - last_cared_at, 0 ].max
    if resting?(at: now)
      elapsed = [ elapsed - REST_MINUTES.minutes, 0 ].max
    end

    {
      hunger: decay_value(base_hunger, HUNGER_PER_HOUR, elapsed, rising: true),
      happiness: decay_value(base_happiness, HAPPINESS_PER_HOUR, elapsed),
      energy: decay_value(base_energy, ENERGY_PER_HOUR, elapsed)
    }
  end

  def hunger(at: Time.current) = stats(at: at)[:hunger]
  def happiness(at: Time.current) = stats(at: at)[:happiness]
  def energy(at: Time.current) = stats(at: at)[:energy]

  # A pet whose stats have bottomed out needs the gentle rescue path.
  def distressed?(at: Time.current)
    stats(at: at).values.any? { |value| value <= 0 }
  end

  def resting?(at: Time.current)
    resting_until.present? && resting_until > at
  end

  # Seconds left in the current rest window.
  def rest_remaining(at: Time.current)
    return 0 unless resting?(at: at)

    [ resting_until - at, 0 ].max.to_i
  end

  def feed!(message: nil, at: Time.current)
    apply_care(:feed, at: at, message: message) do
      self.base_hunger = [ base_hunger + FEED_HUNGER, 100 ].min
    end
  end

  def play!(message: nil, at: Time.current)
    apply_care(:play, at: at, message: message) do
      self.base_happiness = [ base_happiness + PLAY_HAPPINESS, 100 ].min
      self.base_energy = [ base_energy - PLAY_ENERGY_COST, 0 ].max
    end
  end

  def rest!(message: nil, at: Time.current)
    apply_care(:rest, at: at, message: message) do
      self.base_energy = [ base_energy + REST_ENERGY, 100 ].min
      self.resting_until = at.to_time + REST_MINUTES.minutes
    end
  end

  # Gentle rescue/revive for a neglected pet whose stats bottomed out:
  # comfort it back to a stable, awake state.
  def rescue!(message: nil, at: Time.current)
    apply_care(:rescue, at: at, message: message) do
      self.base_hunger = RESCUE_BOOST
      self.base_happiness = RESCUE_BOOST
      self.base_energy = RESCUE_BOOST
    end
  end

  private

  # Shared plumbing for every care action: fold any decay that accumulated
  # since the last care event into the stored bases so the post-action stats
  # are correct immediately, run the action's stat change, stamp the new
  # care time, log the event, and persist.
  def apply_care(action, at:, message:)
    now = at.to_time
    fold_decay!(stats(at: now))

    yield

    self.last_cared_at = now
    self.resting_until = nil unless action == :rest

    message ||= default_message(action)
    care_events.create!(action: action, message: message, occurred_at: now)

    save!
    care_events.reload
    { stats: stats(at: now), action: action, message: message }
  end

  # Move the computed live stats back into the stored bases, so the next
  # care action starts from where the pet actually is (not from a stale
  # snapshot that already decayed).
  def fold_decay!(live)
    self.base_hunger = live[:hunger]
    self.base_happiness = live[:happiness]
    self.base_energy = live[:energy]
  end

  def decay_value(base, per_hour, elapsed_seconds, rising: false)
    change = per_hour * (elapsed_seconds / 3600.0)
    value = rising ? base + change : base - change
    value.round.clamp(0, 100)
  end

  def default_message(action)
    case action
    when :feed
      base_hunger >= 90 ? "#{name} is full and happy!" : "#{name} gobbles up the snack!"
    when :play
      "#{name} bounces with joy!"
    when :rest
      "#{name} curls up for a cozy nap."
    when :rescue
      "#{name} stirs back to life — rescued!"
    when :adopt
      "Welcome home, #{name}!"
    end
  end
end
