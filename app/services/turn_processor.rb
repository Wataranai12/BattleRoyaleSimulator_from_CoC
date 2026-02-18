# frozen_string_literal: true

class TurnProcessor
  def initialize(attacker_participant, battle)
    @attacker = attacker_participant
    @battle = battle
  end

  def execute
    # ターゲット選択
    target = select_target
    return unless target

    # 攻撃手段選択
    attack_method = @attacker.character.best_attack
    return unless attack_method

    # 攻撃実行
    perform_attack(attack_method, target)
  end

  private

  def select_target
    potential_targets = @battle.battle_participants.active
                               .where.not(id: @attacker.id)

    # チーム戦の場合は敵チームのみ
    potential_targets = potential_targets.where.not(team_id: @attacker.team_id) if @battle.team? && @attacker.team_id

    potential_targets.sample
  end

  def perform_attack(attack_method, target)
    skill = attack_method.skill

    # 攻撃判定
    attack_roll = rand(1..100)
    success_rate = skill.success

    create_attack_log(attack_method, target)

    if attack_roll <= success_rate
      # 命中判定成功 → 回避判定
      perform_dodge_check(attack_method, target)
    else
      # 攻撃失敗
      create_miss_log(target)
    end
  end

  def perform_dodge_check(attack_method, target)
    dodge_skill = target.character.dodge_skill
    dodge_roll = rand(1..100)

    if dodge_roll <= dodge_skill
      # 回避成功
      create_dodge_log(target)
    else
      # 回避失敗 → ダメージ
      apply_damage(attack_method, target)
    end
  end

  def apply_damage(attack_method, target)
    damage = attack_method.calculate_damage(
      apply_db: attack_method.can_apply_db,
      apply_ma: attack_method.can_apply_ma
    )

    target.take_damage(damage)
    @attacker.deal_damage(damage)

    create_damage_log(target, damage)

    # AI実況をキューに追加
    GeminiNarrationJob.perform_later(@battle.id, @battle.battle_logs.last.id)
  end

  def create_attack_log(attack_method, target)
    @battle.battle_logs.create!(
      character: @attacker.character,
      target: target.character,
      round: @battle.current_round,
      message: "#{@attacker.character.name}は#{attack_method.show_name}で#{target.character.name}を攻撃！",
      action_type: 'attack'
    )
  end

  def create_miss_log(target)
    @battle.battle_logs.create!(
      character: @attacker.character,
      target: target.character,
      round: @battle.current_round,
      message: '攻撃は外れた！',
      action_type: 'attack'
    )
  end

  def create_dodge_log(target)
    @battle.battle_logs.create!(
      character: @attacker.character,
      target: target.character,
      round: @battle.current_round,
      message: "#{target.character.name}は回避した！",
      action_type: 'dodge'
    )
  end

  def create_damage_log(target, damage)
    @battle.battle_logs.create!(
      character: @attacker.character,
      target: target.character,
      round: @battle.current_round,
      message: "#{target.character.name}に#{damage}ダメージ！（残りHP: #{target.current_hp}）",
      action_type: 'damage',
      details: { damage: damage, remaining_hp: target.current_hp }
    )
  end
end
