# frozen_string_literal: true

module BattlesHelper
  def log_badge_class(action_type)
    case action_type
    when '戦闘開始', 'ラウンド開始'
      'bg-info text-dark'
    when '攻撃'
      'bg-primary'
    when '戦闘不能'
      'bg-danger'
    when '戦闘終了'
      'bg-success'
    else
      'bg-secondary'
    end
  end
end
