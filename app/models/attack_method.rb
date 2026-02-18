# frozen_string_literal: true

class AttackMethod < ApplicationRecord
  belongs_to :character
  belongs_to :skill
  has_one :default_condition, dependent: :destroy

  validates :show_name, :weapon_name, :base_damage, presence: true

  # ✅ 複合ダメージ式に対応
  # OK: 1d6 / 1d4+2 / 1d4+1d4 / 1d4+2+1d4 / 0 / 特殊
  validates :base_damage, format: {
    with: /\A(0|特殊|((\d+d\d+|\d+)([+-](\d+d\d+|\d+))*))\z/i,
    message: 'は有効なダメージ式ではありません（例: 1d6, 1d4+2, 1d4+1d4, 0）'
  }

  enum condition_type: {
    grappling: 0,
    grappled: 1,
    stunned: 2,
    poisoned: 3,
    shocked: 4
  }
end
