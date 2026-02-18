# frozen_string_literal: true

class AttackMethod < ApplicationRecord
  belongs_to :character
  belongs_to :skill
  has_one :default_condition, dependent: :destroy

  validates :show_name, :weapon_name, :base_damage, presence: true

  # ダメージ式のバリデーション（複合ダメージ式対応）
  validates :base_damage, format: {
    with: /\A(\d+d\d+|[+-]?\d+)(\s*[+-]\s*(\d+d\d+|\d+))*\z/,
    message: 'は正しいダイス式である必要があります（例: 1d6+2, 1d4+1d4）'
  }

  enum condition_type: {
    grappling: 0,
    grappled: 1,
    stunned: 2,
    poisoned: 3,
    shocked: 4
  }
end
