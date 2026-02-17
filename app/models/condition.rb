# frozen_string_literal: true

class Condition < ApplicationRecord
  belongs_to :battle_participant
  # 状態の付与者を「origin」として参照できるようにする
  belongs_to :origin, class_name: 'BattleParticipant', foreign_key: 'origin_participant_id', optional: true

  enum condition_type: {
    grappling: 0,  # 自分が組み付いている
    grappled: 1,   # 相手に組み付かれている
    stunned: 2,
    poisoned: 3,
    shocked: 4
  }
end
