# frozen_string_literal: true

class BattleSimulator
  attr_reader :battle, :participants, :current_turn_order

  def initialize(battle)
    @battle = battle
    @participants = battle.battle_participants.includes(
      character: [:characteristics, :skills, { attack_methods: :default_condition }]
    ).to_a
    @current_turn_order = []
    @condition_manager = BattleService::ConditionManager.new(method(:log_event))
    @attack_resolver   = BattleService::AttackResolver.new(@participants, method(:log_event))
  end

  def start_battle
    @current_turn_order = @participants.select(&:is_active).sort_by { |p| -get_dex(p) }
    battle.update!(current_round: 0)
    first_char = @current_turn_order.first&.character
    log_event('戦闘開始', "参加者: #{@current_turn_order.map { |p| p.character.name }.join(', ')}", character: first_char)
  end

  def execute_round
    return if battle.is_finished?

    if @current_turn_order.empty?
      @current_turn_order = @participants.select(&:is_active).sort_by { |p| -get_dex(p) }
    end

    battle.increment!(:current_round)
    log_event('ラウンド開始', "第#{battle.current_round}ラウンド", character: @participants.find(&:is_active)&.character)

    # 状態異常tick・戦闘不能チェック
    @participants.each do |p|
      @condition_manager.tick_conditions(p)
      if p.current_hp <= 0 && p.is_active
        p.update!(is_active: false)
        log_event('戦闘不能', "#{p.character.name} は戦闘不能になった", character: p.character)
      end
    end

    return if check_battle_end

    @current_turn_order.select(&:is_active).each do |attacker|
      next unless attacker.is_active

      targets = get_valid_targets(attacker)
      break if targets.empty?

      @attack_resolver.resolve(attacker, targets.sample)
      break if check_battle_end
    end
  end

  def battle_summary
    {
      round: battle.current_round,
      finished: battle.is_finished?,
      participants: @participants.map do |p|
        { id: p.id, name: p.character.name, hp: p.current_hp,
          max_hp: p.character.max_hp, is_active: p.is_active, team: p.team&.where_team }
      end
    }
  end

  private

  def check_battle_end
    active = @participants.select(&:is_active)
    return false if active.size > 1 && !(battle.battle_mode == 'team' && active.map(&:team_id).uniq.size == 1)

    battle.update!(is_finished: true)
    if active.size == 1
      log_event('戦闘終了', "#{active.first.character.name} の勝利！", character: active.first.character)
    elsif active.size == 0
      log_event('戦闘終了', '全員戦闘不能', character: @participants.first&.character)
    else
      log_event('戦闘終了', "チーム#{active.first.team.where_team} の勝利！", character: active.first.character)
    end
    true
  end

  def get_valid_targets(attacker)
    if battle.battle_mode == 'individual'
      @participants.select { |p| p.is_active && p.id != attacker.id }
    else
      @participants.select { |p| p.is_active && p.team_id != attacker.team_id }
    end
  end

  def get_dex(participant)
    participant.character.characteristics.find_by(name: 'dex')&.value || 10
  end

  def log_event(action_type, message, character: nil, target: nil)
    BattleLog.create!(
      battle: battle,
      character_id: character&.id,
      target_id: target&.id,
      round: battle.current_round,
      action_type: action_type,
      message: message
    )
  end
end
