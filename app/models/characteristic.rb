# frozen_string_literal: true

class Characteristic < ApplicationRecord
  belongs_to :character

  VALID_NAMES = %w[str con pow dex app siz int edu hp mp san luck].freeze

  validates :value, presence: true, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 110
  }

  # ✅ if: :persisted? を1つだけにする（2行あったのを修正）
  validates :name, uniqueness: { scope: :character_id }, if: :persisted?
end
