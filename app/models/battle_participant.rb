class BattleParticipant < ApplicationRecord
  belongs_to :character
  belongs_to :battle
  belongs_to :team
  has_many :conditions, dependent: :destroy
end
