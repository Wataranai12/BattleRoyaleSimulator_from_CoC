class Skill < ApplicationRecord
  belongs_to :character
  has_many :attack_methods, dependent: :destroy
  validates :name, presence: true
  validates :success, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 99 }
  validates :category, presence: true, inclusion: { in: %w(attack dodge martialarts grapple other) }
end
