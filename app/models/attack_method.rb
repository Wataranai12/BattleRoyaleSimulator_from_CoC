class AttackMethod < ApplicationRecord
  belongs_to :character
  belongs_to :skill
  def calculate_effect_value(participant)
    case condition_type
    when "grappling", "grappled"
      # 組み付きの場合、攻撃側のSTRを返す
      participant.character.characteristics.find_by(name: "str")&.value
    when "poisoned"
      # 毒の場合は保存されている固定値を返す
      self.effect_value
    else
      0
    end
  end
end
