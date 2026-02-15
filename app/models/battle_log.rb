class BattleLog < ApplicationRecord
  belongs_to :battle
  belongs_to :character
end
