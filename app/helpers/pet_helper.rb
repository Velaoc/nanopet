# frozen_string_literal: true

module PetHelper
  # Look → palette and a tiny personality note. Mochi is the seeded default.
  PALETTES = {
    "mochi" => {
      body: "#F2B8C6", body_dark: "#C97B93", belly: "#FFF3E8",
      cheek: "#E76F8F", accent: "#7C4DFF", name: "Mochi"
    },
    "blob" => {
      body: "#A7C7E7", body_dark: "#5F8FC4", belly: "#EAF4FF",
      cheek: "#4E8EDB", accent: "#FF8A5C", name: "Blob"
    },
    "gummy" => {
      body: "#B9E4C9", body_dark: "#6FBE8F", belly: "#F0FBF4",
      cheek: "#3FA96F", accent: "#FFD166", name: "Gummy"
    }
  }.freeze

  def pet_palettes
    PALETTES
  end

  def pet_palette(look)
    PALETTES.fetch(look, PALETTES["mochi"])
  end

  def pet_slump?(stats) = stats[:energy] < 25
  def pet_droop?(stats) = stats[:happiness] < 25
  def pet_asleep?(pet, stats) = pet.resting? || stats[:energy] >= 100

  # One short line about how the pet is feeling, driven by its live stats.
  def pet_tagline(pet, stats)
    if pet.resting?
      "#{pet.name} is fast asleep. Rest pauses hunger while energy recovers."
    elsif stats[:hunger] < 25
      "#{pet.name} is hungry — a snack would go down well."
    elsif stats[:happiness] < 25
      "#{pet.name} is feeling blue and would love to play."
    elsif stats[:energy] < 25
      "#{pet.name} is worn out and needs a rest."
    elsif stats[:hunger] >= 85 && stats[:happiness] >= 75 && stats[:energy] >= 75
      "#{pet.name} is full and happy!"
    else
      "#{pet.name} is doing alright. A little care goes a long way."
    end
  end
end
