# frozen_string_literal: true

class Battle < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :winner, class_name: 'Character', optional: true
  has_many :battle_participants, dependent: :destroy
  has_many :characters, through: :battle_participants
  has_many :teams, dependent: :destroy
  has_many :battle_logs, dependent: :destroy
  attribute :battle_mode, :integer
  enum battle_mode: { individual: 0, team: 1 }
  validates :current_round, numericality: { greater_than_or_equal_to: 0 }

  scope :ongoing, -> { where(is_finished: false) }
  scope :finished, -> { where(is_finished: true) }
  scope :recent, -> { order(created_at: :desc) }

  # 戦闘開始可能か
  def can_start?
    !is_finished && battle_participants.count >= 2
  end

  # 現在アクティブな参加者
  def active_participants
    battle_participants.where(is_active: true, is_join: true)
  end

  # 戦闘終了判定
  def check_finish_condition?
    active = active_participants

    return active.count <= 1 if individual?

    # 個人戦: 1人だけ残っている

    # チーム戦: 1チームだけ残っている
    active_teams = active.map(&:team_id).uniq.compact
    active_teams.size <= 1
  end

  # 勝者を決定
  def determine_winner
    return nil unless is_finished

    survivor = active_participants.first
    survivor&.character
  end

  # 戦闘時間
  def duration
    return nil unless started_at

    end_time = finished_at || Time.current
    end_time - started_at
  end
end
