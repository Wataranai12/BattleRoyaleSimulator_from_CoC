class Character < ApplicationRecord
  belongs_to :user
  has_many :characteristics, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :attack_methods, dependent: :destroy
  has_many :battle_participants
  has_many :battles, through: :battle_participants

  # 子要素も一緒にバリデーションする
  validates_associated :characteristics
  validates_associated :skills

  # accepts_nested_attributes_for を使うと、txt解析後に一括で保存しやすくなります
  accepts_nested_attributes_for :characteristics, :skills, :attack_methods
end
