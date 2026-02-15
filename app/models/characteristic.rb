class Characteristic < ApplicationRecord
  belongs_to :character
  validates :name, presence: true, inclusion: { in: %w(str con pow dex app siz int edu) }
  validates :value, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 99 }
end
