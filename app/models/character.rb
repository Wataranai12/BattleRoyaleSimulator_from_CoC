# frozen_string_literal: true

class Character < ApplicationRecord
  belongs_to :user

  has_many :characteristics, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :attack_methods, dependent: :destroy
  has_many :battle_participants, dependent: :destroy
  has_many :battles, through: :battle_participants

  accepts_nested_attributes_for :characteristics, :skills, :attack_methods,
                                allow_destroy: true,
                                reject_if: :all_blank

  validates :name, presence: true, length: { maximum: 100 }
  validates :damage_bonus, format: {
    with: /\A(\+\d+d\d+|0|-\d+d\d+)\z/i, # 6版は+1d4, 0, -1d4など
    allow_blank: true
  }

  # スコープ
  scope :samples, -> { where(is_sample: true) }
  scope :user_characters, ->(user) { where(user: user) }

  def calculate_damage_bonus
    total = str + siz

    case total
    when 0..12
      '-1d6'
    when 13..16
      '-1d4'
    when 17..24
      '0'
    when 25..32
      '+1d4'
    else
      '+1d6'
    end
  end
end
