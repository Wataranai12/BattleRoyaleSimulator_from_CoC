# frozen_string_literal: true

class Skill < ApplicationRecord
  belongs_to :character
  has_many :attack_methods, dependent: :destroy

  # 6版の初期値技能定義
  DEFAULT_SKILLS = {
    # 格闘技能（初期値あり）
    'こぶし' => { category: :martialarts, base_value: 50, always_available: true },
    'キック' => { category: :martialarts, base_value: 25, always_available: true },
    '頭突き' => { category: :martialarts, base_value: 10, always_available: true },
    '組み付き' => { category: :grapple, base_value: :dex_x2, always_available: true }, # DEX×2%

    # 回避
    '回避' => { category: :dodge, base_value: :dex_x2, always_available: true }, # DEX×2%

    # 武器技能（初期値0%だが、故障時などに常に使用可能）
    '拳銃' => { category: :attack, base_value: 0, always_available: true },
    'ライフル' => { category: :attack, base_value: 0, always_available: true },
    'ショットガン' => { category: :attack, base_value: 0, always_available: true },
    'サブマシンガン' => { category: :attack, base_value: 0, always_available: true },
    '投擲' => { category: :attack, base_value: 0, always_available: true },

    # その他の近接武器（初期値0%）
    'ナイフ' => { category: :attack, base_value: 0, always_available: false },
    '棍棒' => { category: :attack, base_value: 0, always_available: false },
    '剣' => { category: :attack, base_value: 0, always_available: false },
    '斧' => { category: :attack, base_value: 0, always_available: false },
    'チェーンソー' => { category: :attack, base_value: 0, always_available: false },
    '鞭' => { category: :attack, base_value: 0, always_available: false },

    # マーシャルアーツ（初期値1%）
    'マーシャルアーツ' => { category: :martialarts, base_value: 1, always_available: false }
  }.freeze

  enum category: {
    other: 0,
    dodge: 1,
    attack: 2,
    martialarts: 3,
    grapple: 4
  }, _prefix: true

  # バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :character_id, message: 'は既に登録されています' }
  validates :category, presence: true
  validates :success, presence: true,
                      numericality: {
                        only_integer: true,
                        greater_than_or_equal_to: 1,  # 初期値は保存しないので1以上
                        less_than_or_equal_to: 99     # 6版は最大99%
                      }

  # カスタムバリデーション：初期値と同じ場合は保存させない
  validate :cannot_be_default_value
end
