# frozen_string_literal: true

class Skill < ApplicationRecord
  belongs_to :character
  has_many :attack_methods, dependent: :destroy

  DEFAULT_SKILLS = {
    'こぶし' => { category: :martialarts, base_value: 50, always_available: true },
    'キック' => { category: :martialarts, base_value: 25, always_available: true },
    '頭突き' => { category: :martialarts, base_value: 10, always_available: true },
    '組み付き' => { category: :grapple, base_value: :dex_x2, always_available: true },
    '回避' => { category: :dodge, base_value: :dex_x2, always_available: true },
    '拳銃' => { category: :attack, base_value: 0, always_available: true },
    'ライフル' => { category: :attack, base_value: 0, always_available: true },
    'ショットガン' => { category: :attack, base_value: 0, always_available: true },
    'サブマシンガン' => { category: :attack, base_value: 0, always_available: true },
    '投擲' => { category: :attack, base_value: 0, always_available: true },
    'ナイフ' => { category: :attack, base_value: 0, always_available: false },
    '棍棒' => { category: :attack, base_value: 0, always_available: false },
    '剣' => { category: :attack, base_value: 0, always_available: false },
    '斧' => { category: :attack, base_value: 0, always_available: false },
    'チェーンソー' => { category: :attack, base_value: 0, always_available: false },
    '鞭' => { category: :attack, base_value: 0, always_available: false },
    'マーシャルアーツ' => { category: :martialarts, base_value: 1, always_available: false }
  }.freeze

  enum category: {
    other: 0,
    dodge: 1,
    attack: 2,
    martialarts: 3,
    grapple: 4
  }, _prefix: true

  validates :name, uniqueness: { scope: :character_id }, if: :persisted?
  validates :category, presence: true
  validates :success, presence: true,
                      numericality: {
                        only_integer: true,
                        greater_than_or_equal_to: 1,
                        less_than_or_equal_to: 99
                      }

  # ✅ cannot_be_default_value を削除
  # 理由: character未保存時にDEXが0になり判定が狂うため
  # パーサー側で初期値スキップの制御を行う

  scope :combat_skills, -> { where.not(category: :other) }
  scope :attack_skills, -> { where(category: %i[attack martialarts grapple]) }
  scope :by_success_rate, -> { order(success: :desc) }
  scope :custom_skills, -> { where.not(name: DEFAULT_SKILLS.keys) }

  class << self
    def default_skill_names
      DEFAULT_SKILLS.keys
    end

    def default_skill?(skill_name)
      DEFAULT_SKILLS.key?(skill_name)
    end

    def default_value_for(skill_name, character = nil)
      skill_data = DEFAULT_SKILLS[skill_name]
      return 0 unless skill_data

      base_value = skill_data[:base_value]

      if base_value.is_a?(Symbol) && character&.persisted?
        case base_value
        when :dex_x2
          (character.get_characteristic('dex') * 2).floor
        else
          0
        end
      else
        base_value.is_a?(Integer) ? base_value : 0
      end
    end

    def always_available_skills
      DEFAULT_SKILLS.select { |_name, data| data[:always_available] }.keys
    end
  end

  def combat_skill?
    category_attack? || category_martialarts? || category_grapple?
  end

  def attack_skill?
    category_attack? || category_martialarts? || category_grapple?
  end

  def display_category
    I18n.t("activerecord.attributes.skill.categories.#{category}",
           default: category.humanize)
  end

  def success_rate_percentage
    "#{success}%"
  end

  def default_skill?
    self.class.default_skill?(name)
  end
end
