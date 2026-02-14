class User < ApplicationRecord
  authenticates_with_sorcery!

  validates :name, presence: true, length: { maximum: 255 }

  # パスワードは新規作成か変更時のみ、3文字以上必要
  validates :password, length: { minimum: 3 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:crypted_password] }

  # メールアドレスとユーザー名は必須かつ一意
  validates :email, uniqueness: true, presence: true
  validates :name, presence: true
end
