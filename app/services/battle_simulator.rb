# frozen_string_literal: true

# CoC 6版対応 戦闘シミュレーター
class BattleSimulator
  attr_reader :battle, :participants, :current_turn_order

  def initialize(battle)
    @battle = battle
    @participants = battle.battle_participants.includes(character: [:characteristics, :skills, :attack_methods]).to_a
    @current_turn_order = []
  end

  # 戦闘開始：DEX順で行動順決定
  def start_battle
    @current_turn_order = @participants
      .select(&:is_active)
      .sort_by { |p| -get_dex(p) } # DEX降順
    
    battle.update!(current_round: 1)
    log_event('戦闘開始', "参加者: #{@current_turn_order.map { |p| p.character.name }.join(', ')}")
  end

  # 次のラウンド開始
  def next_round
    return if battle.is_finished?
    
    battle.increment!(:current_round)
    log_event('ラウンド開始', "第#{battle.current_round}ラウンド")
    
    # 行動不能チェック（HP 0以下）
    @participants.each do |p|
      if p.current_hp <= 0 && p.is_active
        p.update!(is_active: false)
        log_event('戦闘不能', "#{p.character.name} は戦闘不能になった")
      end
    end
    
    check_battle_end
  end

  # 自動行動：全員が順番に攻撃
  def execute_auto_turn
    active = @current_turn_order.select(&:is_active)
    
    active.each do |attacker|
      next unless attacker.is_active
      
      # ターゲット選択（ランダム）
      targets = get_valid_targets(attacker)
      break if targets.empty? # 敵がいなければ終了
      
      target = targets.sample
      execute_attack(attacker, target)
      
      # 毎回戦闘終了チェック
      break if check_battle_end
    end
  end

  # 攻撃実行
  def execute_attack(attacker, defender)
    char = attacker.character
    
    # 攻撃手段選択（ランダム）
    attack_methods = char.attack_methods.includes(:skill)
    return log_event('エラー', "#{char.name} の攻撃手段がありません") if attack_methods.empty?
    
    attack_method = attack_methods.sample
    skill = attack_method.skill
    
    # 攻撃判定
    roll = rand(1..100)
    success = roll <= skill.success
    
    if success
      # ダメージ計算
      damage = calculate_damage(attack_method, char)
      
      # 回避判定
      dodge_skill = defender.character.skills.find_by(name: '回避')
      dodge_roll = rand(1..100)
      dodge_success = dodge_skill && dodge_roll <= dodge_skill.success
      
      if dodge_success
        log_event('攻撃', "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避成功(#{dodge_roll})")
      else
        # ダメージ適用
        new_hp = [defender.current_hp - damage, 0].max
        defender.update!(current_hp: new_hp)
        
        log_event('攻撃', "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})")
        
        # 戦闘不能チェック
        if new_hp <= 0
          defender.update!(is_active: false)
          log_event('戦闘不能', "#{defender.character.name} は戦闘不能になった")
        end
      end
    else
      log_event('攻撃', "#{char.name} の #{attack_method.show_name}(#{roll}) → 失敗")
    end
  end

  # ダメージ計算（ダイス式をパース）
  def calculate_damage(attack_method, character)
    formula = attack_method.base_damage
    
    # "1d6+2+1d4" のような式を解析
    total = 0
    parts = formula.scan(/(\d+)d(\d+)|([+-]?\d+)/)
    
    parts.each do |dice_count, dice_sides, fixed|
      if dice_count && dice_sides
        # ダイスロール
        dice_count.to_i.times { total += rand(1..dice_sides.to_i) }
      elsif fixed
        # 固定値
        total += fixed.to_i
      end
    end
    
    # DB適用
    if attack_method.can_apply_db
      db = parse_damage_bonus(character.damage_bonus)
      total += db
    end
    
    [total, 0].max
  end

  # DBをパース（"+1d4" → 実際のダイス結果）
  def parse_damage_bonus(db_str)
    return 0 if db_str.blank? || db_str == '0'
    
    match = db_str.match(/([+-]?)(\d+)d(\d+)/)
    return 0 unless match
    
    sign = match[1] == '-' ? -1 : 1
    count = match[2].to_i
    sides = match[3].to_i
    
    result = 0
    count.times { result += rand(1..sides) }
    sign * result
  end

  # 有効なターゲットを取得
  def get_valid_targets(attacker)
    if battle.battle_mode == 'individual'
      # 個人戦：自分以外全員
      @participants.select { |p| p.is_active && p.id != attacker.id }
    else
      # チーム戦：敵チームのみ
      @participants.select { |p| p.is_active && p.team_id != attacker.team_id }
    end
  end

  # 戦闘終了判定
  def check_battle_end
    active = @participants.select(&:is_active)
    
    if active.size <= 1
      battle.update!(is_finished: true)
      
      if active.size == 1
        winner = active.first
        log_event('戦闘終了', "#{winner.character.name} の勝利！")
      else
        log_event('戦闘終了', '全員戦闘不能')
      end
      
      return true
    end
    
    # チーム戦：1チームのみ残っているか
    if battle.battle_mode == 'team'
      active_teams = active.map(&:team_id).uniq
      if active_teams.size == 1
        battle.update!(is_finished: true)
        team_name = active.first.team.where_team
        log_event('戦闘終了', "チーム#{team_name} の勝利！")
        return true
      end
    end
    
    false
  end

  # DEX取得
  def get_dex(participant)
    char = participant.character
    char.characteristics.find_by(name: 'dex')&.value || 10
  end

  # ログ記録
  def log_event(action_type, message, character: nil, target: nil)
    BattleLog.create!(
      battle: battle,
      round: battle.current_round,
      action_type: action_type,
      message: message
    )
  end

  # 戦闘状況サマリー
  def battle_summary
    {
      round: battle.current_round,
      finished: battle.is_finished?,
      participants: @participants.map do |p|
        {
          id: p.id,
          name: p.character.name,
          hp: p.current_hp,
          max_hp: p.character.max_hp,
          is_active: p.is_active,
          team: p.team&.where_team
        }
      end
    }
  end
end
