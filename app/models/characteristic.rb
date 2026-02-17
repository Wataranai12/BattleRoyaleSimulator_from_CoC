# frozen_string_literal: true

class Characteristic < ApplicationRecord
  belongs_to :character

  VALID_NAMES = %w[str con pow dex app siz int edu hp mp san luck].freeze

  validates :name, presence: true, inclusion: { in: VALID_NAMES }
  validates :value, presence: true, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 110
  }
  validates :name, uniqueness: { scope: :character_id }

  # 能力値取得メソッド（6版は3-18の範囲だが、%表記では×5が基本）
  def get_characteristic(name)
    characteristics.find_by(name: name)&.value || 0
  end

  # 6版では能力値を%換算で使うことが多い
  def get_characteristic_percentage(name)
    (get_characteristic(name) * 5).floor
  end

  def str
    get_characteristic('str')
  end

  def dex
    get_characteristic('dex')
  end

  def hp
    get_characteristic('hp')
  end

  def pow
    get_characteristic('pow')
  end

  def con
    get_characteristic('con')
  end

  def siz
    get_characteristic('siz')
  end

  def int
    get_characteristic('int')
  end

  def edu
    get_characteristic('edu')
  end

  def app
    get_characteristic('app')
  end

  # アイデア (INT×5)
  def idea
    (int * 5).floor
  end

  # 知識 (EDU×5)
  def knowledge
    (edu * 5).floor
  end

  # 幸運 (POW×5)
  def luck
    (pow * 5).floor
  end
end
