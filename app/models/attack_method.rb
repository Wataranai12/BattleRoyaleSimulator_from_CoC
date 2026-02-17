# frozen_string_literal: true

class AttackMethod < ApplicationRecord
  belongs_to :character
  belongs_to :skill
  validates :show_name, :weapon_name, :base_damage, presence: true
  validates :base_damage, format: { with: /\A\d+d\d+(\+\d+d\d+)?(\+DB)?\z/i }

  # 状態異常の定義
  enum condition_type: {
    grappling: 0,
    grappled: 1,
    stunned: 2,
    poisoned: 3,
    shocked: 4
  }
end
