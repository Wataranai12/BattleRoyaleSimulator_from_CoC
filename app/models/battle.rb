class Battle < ApplicationRecord
  has_many :battle_participants, dependent: :destroy
  has_many :characters, through: :battle_participants
  has_many :battle_logs, dependent: :destroy
end
