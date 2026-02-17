# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :battle
  has_many :battle_participants
  has_many :characters, through: :battle_participants

  # where_team: "A" / "B" / "C"
  NAMES = %w[A B C].freeze

  validates :where_team, inclusion: { in: NAMES }
end
