# One seeded default pet named Mochi with mid-range stats and a few care
# events, so the app opens straight onto a living pet. Adopting a new pet
# later simply deactivates Mochi.
if Pet.count.zero?
  mochi = Pet.create!(
    name: "Mochi",
    look: "mochi",
    active: true,
    base_hunger: 70,
    base_happiness: 72,
    base_energy: 68,
    last_cared_at: 2.hours.ago
  )

  [
    [ "adopt", "Welcome home, Mochi!", 3.days.ago ],
    [ "feed", "Mochi gobbles up the snack!", 2.hours.ago ],
    [ "play", "Mochi bounces with joy!", 5.hours.ago ],
    [ "rest", "Mochi curls up for a cozy nap.", 1.day.ago ]
  ].each do |action, message, occurred_at|
    mochi.care_events.create!(action: action, message: message, occurred_at: occurred_at)
  end
end
