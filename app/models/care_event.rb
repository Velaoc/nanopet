# frozen_string_literal: true

# One logged care action (feed / play / rest / rescue / adopt) with the
# moment it happened. The care history is the pet's little diary.
class CareEvent < ApplicationRecord
  ACTIONS = Pet::ACTIONS

  belongs_to :pet

  validates :action, inclusion: { in: ACTIONS }
  validates :occurred_at, presence: true
  validates :message, length: { maximum: 200 }
end
