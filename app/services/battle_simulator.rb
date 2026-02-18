# frozen_string_literal: true

# CoC 6版対応 戦闘シミュレーター
class BattleSimulator
  attr_reader :battle, :participants, :current_turn_order

  def initialize(battle)
    @battle = battle
    @participants = battle.battle_participants.includes(
      character: [
        :characteristics,
        :skills,
        { attack_methods: :default_condition }
      ]
    ).to_a
    @current_turn_order = []
  end

  # 戦闘開始：DEX順で行動順決定
  def start_battle
    @current_turn_order = @participants
                          .select(&:is_active)
                          .sort_by { |p| -get_dex(p) } # DEX降順

    battle.update!(current_round: 0)

    # システムログは最初の参加者を character として記録（暫定）
    first_char = @current_turn_order.first&.character
    log_event('戦闘開始', "参加者: #{@current_turn_order.map { |p| p.character.name }.join(', ')}", character: first_char)
  end

  # 1ラウンド実行：全員が順番に攻撃
  def execute_round
    return if battle.is_finished?

    # 行動順を再計算（初回または参加者変更時）
    if @current_turn_order.empty?
      @current_turn_order = @participants
                            .select(&:is_active)
                            .sort_by { |p| -get_dex(p) }
    end

    # ラウンド開始処理
    battle.increment!(:current_round)
    first_active = @participants.find(&:is_active)
    log_event('ラウンド開始', "第#{battle.current_round}ラウンド", character: first_active&.character)

    # 状態異常の duration 減少処理
    @participants.each do |p|
      p.conditions.where(is_active: true).each do |condition|
        next unless condition.duration.present?
        condition.decrement!(:duration)
        if condition.duration <= 0
          condition.update!(is_active: false)
          log_event('状態異常解除', "#{p.character.name} の #{condition.condition_type} が解除された", character: p.character)
        end
      end

      # 行動不能チェック（HP 0以下）
      if p.current_hp <= 0 && p.is_active
        p.update!(is_active: false)
        log_event('戦闘不能', "#{p.character.name} は戦闘不能になった", character: p.character)
      end
    end

    # 戦闘終了チェック
    return if check_battle_end

    # 全員が順番に攻撃
    active = @current_turn_order.select(&:is_active)
    active.each do |attacker|
      next unless attacker.is_active

      targets = get_valid_targets(attacker)
      break if targets.empty?

      target = targets.sample
      execute_attack(attacker, target)

      # 攻撃後に戦闘終了チェック
      break if check_battle_end
    end
  end

  # 攻撃実行
  def execute_attack(attacker, defender)
    char = attacker.character

    # 組み付き状態のチェック
    grapple_condition = attacker.conditions.find_by(condition_type: 'grappling', is_active: true)
    grappled_condition = attacker.conditions.find_by(condition_type: 'grappled', is_active: true)

    # grappledされている場合はSTR対抗判定を試みる
    if grappled_condition
      execute_str_contest(attacker, grappled_condition)
      return
    end

    # 攻撃手段選択
    attack_methods = char.attack_methods.includes(:skill, :default_condition)

    # grapplingしている場合は組み付き攻撃のみ可能
    attack_methods = attack_methods.joins(:skill).where(skills: { category: 'grapple' }) if grapple_condition

    if attack_methods.empty?
      log_event('エラー', "#{char.name} の攻撃手段がありません", character: char)
      return
    end

    attack_method = attack_methods.sample
    skill = attack_method.skill

    # default_condition を明示的に reload（念のため）
    attack_method.reload if attack_method.persisted?

    # Nerf状態の確認（技能成功率-20%）
    skill_success = skill.success
    nerf_condition = attacker.conditions.find_by(condition_type: 'nerf', is_active: true)
    skill_success = [skill_success - 20, 0].max if nerf_condition

    # 攻撃判定
    roll = DiceRoller.percentile
    is_critical = roll <= 5
    is_fumble = roll >= 96
    success = roll <= skill_success

    # ファンブル（致命的失敗）
    if is_fumble
      damage = 1
      new_hp = [attacker.current_hp - damage, 0].max
      attacker.update!(current_hp: new_hp)

      # Nerf状態異常を付与（2ラウンド後に解除）
      attacker.conditions.create!(
        condition_type: 'nerf',
        duration: 2,
        is_active: true,
        effect_value: -20
      )

      log_event('ファンブル',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → ファンブル！ 自分に #{damage}ダメージ、2ラウンド技能-20% (HP: #{attacker.current_hp + damage} → #{new_hp})", character: char)

      # 自滅で戦闘不能
      if new_hp <= 0
        attacker.update!(is_active: false)
        log_event('戦闘不能', "#{char.name} は戦闘不能になった", character: char)
      end
      return
    end

    # 攻撃失敗
    unless success
      log_event('攻撃', "#{char.name} の #{attack_method.show_name}(#{roll}) → 失敗", character: char)
      return
    end

    # 組み付き技能の場合
    if skill.category == 'grapple'
      # grapplingしている場合は絞め技（ダメージ攻撃）
      if grapple_condition
        damage = calculate_grapple_damage(char)
        new_hp = [defender.current_hp - damage, 0].max
        defender.update!(current_hp: new_hp)

        log_event('組み付き',
                  "#{char.name} の絞め技 → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})", character: char, target: defender.character)

        # 戦闘不能チェック
        if new_hp <= 0
          defender.update!(is_active: false)
          log_event('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)

          # 組み付き解除
          grapple_condition.update!(is_active: false)
          defender_grappled = defender.conditions.find_by(condition_type: 'grappled', is_active: true)
          defender_grappled&.update!(is_active: false)
        end
        return
      end

      # 新規組み付き
      # 回避判定（grappledされている相手は回避不可）
      defender_grappled = defender.conditions.find_by(condition_type: 'grappled', is_active: true)

      unless defender_grappled
        dodge_skill = defender.character.skills.find_by(name: '回避')
        dodge_roll = DiceRoller.percentile
        dodge_critical = dodge_roll <= 5
        dodge_success = dodge_skill && dodge_roll <= dodge_skill.success

        # 回避クリティカル → 反撃
        if dodge_critical && dodge_skill
          log_event('回避',
                    "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避クリティカル(#{dodge_roll})！ 反撃発動", character: char, target: defender.character)
          execute_counter_attack(defender, attacker)
          return
        end

        # 回避成功
        if dodge_success
          log_event('組み付き',
                    "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避成功(#{dodge_roll})", character: char, target: defender.character)
          return
        end
      end

      # 組み付き成功 → 状態異常付与
      attacker.conditions.create!(
        condition_type: 'grappling',
        duration: nil,  # 相手が脱出するまで継続
        is_active: true,
        origin_participant_id: defender.id
      )

      defender.conditions.create!(
        condition_type: 'grappled',
        duration: nil,  # STR対抗で脱出するまで継続
        is_active: true,
        origin_participant_id: attacker.id
      )

      log_event('組み付き', "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} を組み付いた！",
                character: char, target: defender.character)
      return
    end

    # クリティカル（決定的成功）- 回避不可
    if is_critical
      damage = calculate_damage(attack_method, char)
      new_hp = [defender.current_hp - damage, 0].max
      defender.update!(current_hp: new_hp)

      log_event('クリティカル',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → クリティカル！ #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})", character: char, target: defender.character)

      # 毒攻撃の判定
      default_condition = attack_method.default_condition
      Rails.logger.info "=== 毒DEBUG attack_method_id=#{attack_method.id}, default_condition=#{default_condition.inspect}"

      if default_condition.present? && default_condition.poisoned?  # ← [3,'poisoned'].include?(...) から変更
        execute_poison_check(attacker, defender, default_condition)
      end

      # 戦闘不能チェック
      if new_hp <= 0
        defender.update!(is_active: false)
        log_event('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)
      end
      return
    end

    # 通常の攻撃成功 → 回避判定
    dodge_skill = defender.character.skills.find_by(name: '回避')
    dodge_roll = DiceRoller.percentile
    dodge_critical = dodge_roll <= 5
    dodge_fumble = dodge_roll >= 96
    dodge_success = dodge_skill && dodge_roll <= dodge_skill.success

    # 回避クリティカル → 反撃
    if dodge_critical && dodge_skill
      log_event('回避',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避クリティカル(#{dodge_roll})！ 反撃発動", character: char, target: defender.character)

      # 反撃処理（defender が attacker を攻撃）
      execute_counter_attack(defender, attacker)
      return
    end

    # 回避ファンブル → ダメージ2倍
    if dodge_fumble
      damage = calculate_damage(attack_method, char) * 2
      new_hp = [defender.current_hp - damage, 0].max
      defender.update!(current_hp: new_hp)

      log_event('回避ファンブル',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避ファンブル(#{dodge_roll})！ #{damage}ダメージ (2倍) (HP: #{defender.current_hp + damage} → #{new_hp})", character: char, target: defender.character)

      # 毒攻撃の判定
      default_condition = DefaultCondition.find_by(attack_method_id: attack_method.id)
      if default_condition.present? && [3, 'poisoned'].include?(default_condition.condition_type)
        execute_poison_check(attacker, defender, default_condition)
      end

      # 戦闘不能チェック
      if new_hp <= 0
        defender.update!(is_active: false)
        log_event('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)
      end
      return
    end

    # 回避成功
    if dodge_success
      log_event('攻撃',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避成功(#{dodge_roll})", character: char, target: defender.character)
      return
    end

    # 回避失敗 → ダメージ適用
    damage = calculate_damage(attack_method, char)
    new_hp = [defender.current_hp - damage, 0].max
    defender.update!(current_hp: new_hp)

    log_event('攻撃',
              "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})", character: char, target: defender.character)

    # 毒攻撃の判定（DefaultCondition にある場合）
    # 確実に DB から取得
    default_condition = DefaultCondition.find_by(attack_method_id: attack_method.id)

    if default_condition.present?
      # デバッグログ
      Rails.logger.info '=== 毒判定 DEBUG ==='
      Rails.logger.info "condition_type: #{default_condition.condition_type.inspect} (class: #{default_condition.condition_type.class})"
      Rails.logger.info "effect_value: #{default_condition.effect_value.inspect}"

      # condition_type が 3 (poisoned) の場合
      if [3, 'poisoned'].include?(default_condition.condition_type)
        execute_poison_check(attacker, defender, default_condition)
      else
        Rails.logger.info "条件不一致: #{default_condition.condition_type.inspect} != 3"
      end
    end

    # 戦闘不能チェック
    return unless new_hp <= 0

    defender.update!(is_active: false)
    log_event('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)
  end

  # 反撃処理
  def execute_counter_attack(attacker, defender)
    char = attacker.character

    attack_methods = char.attack_methods.includes(:skill)
    if attack_methods.empty?
      log_event('エラー', "#{char.name} の攻撃手段がありません（反撃失敗）", character: char)
      return
    end

    attack_method = attack_methods.sample
    skill = attack_method.skill

    # 反撃の攻撃判定（クリティカル・ファンブルなし、通常判定のみ）
    roll = DiceRoller.percentile
    success = roll <= skill.success

    unless success
      log_event('反撃', "#{char.name} の反撃 #{attack_method.show_name}(#{roll}) → 失敗", character: char)
      return
    end

    # 反撃成功 → ダメージ適用（回避判定なし）
    damage = calculate_damage(attack_method, char)
    new_hp = [defender.current_hp - damage, 0].max
    defender.update!(current_hp: new_hp)

    log_event('反撃',
              "#{char.name} の反撃 #{attack_method.show_name}(#{roll}) → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})", character: char, target: defender.character)

    # 戦闘不能チェック
    return unless new_hp <= 0

    defender.update!(is_active: false)
    log_event('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)
  end

  # STR対抗判定（grappledされた側が脱出を試みる）
  def execute_str_contest(grappled_participant, grappled_condition)
    grappled_char = grappled_participant.character
    grappler_id = grappled_condition.origin_participant_id
    grappler_participant = @participants.find { |p| p.id == grappler_id }

    unless grappler_participant&.is_active
      # 組み付いていた相手が戦闘不能 → 自動解除
      grappled_condition.update!(is_active: false)
      log_event('組み付き解除', "#{grappled_char.name} は組み付きから解放された（相手が戦闘不能）", character: grappled_char)
      return
    end

    grappler_char = grappler_participant.character

    # STR値を取得
    grappled_str = grappled_char.characteristics.find_by(name: 'str')&.value || 10
    grappler_str = grappler_char.characteristics.find_by(name: 'str')&.value || 10

    # STR対抗判定: rand(1..100) <= 50 + (grappled_str - grappler_str) * 5
    str_diff = grappled_str - grappler_str
    success_rate = 50 + (str_diff * 5)
    roll = rand(1..100)
    success = roll <= success_rate

    if success
      # 脱出成功
      grappled_condition.update!(is_active: false)
      grappling_condition = grappler_participant.conditions.find_by(condition_type: 'grappling', is_active: true)
      grappling_condition&.update!(is_active: false)

      log_event('STR対抗', "#{grappled_char.name} のSTR対抗(#{roll}/#{success_rate}) → 成功！ 組み付きから脱出",
                character: grappled_char)
    else
      # 脱出失敗
      log_event('STR対抗', "#{grappled_char.name} のSTR対抗(#{roll}/#{success_rate}) → 失敗、組み付かれたまま",
                character: grappled_char)
    end
  end

  # 組み付き時のダメージ計算（1d6 + DB）
  def calculate_grapple_damage(character)
    total = rand(1..6)

    # DB適用
    if character.damage_bonus.present?
      db = parse_damage_bonus(character.damage_bonus)
      total += db
    end

    [total, 0].max
  end

  # POT対抗判定（毒攻撃）
  def execute_poison_check(attacker, defender, default_condition)
    defender_char = defender.character
    pot = default_condition.effect_value || 10

    # CON値を取得
    con = defender_char.characteristics.find_by(name: 'con')&.value || 10

    # POT対抗判定: rand(1..100) <= 50 + (CON - POT)
    success_rate = 50 + (con - pot)
    roll = rand(1..100)
    success = roll <= success_rate

    if success
      # POT対抗成功 → 毒無効
      log_event('POT対抗', "#{defender_char.name} のPOT対抗(#{roll}/#{success_rate}) → 成功！ 毒無効", character: defender_char)
    else
      # POT対抗失敗 → 毒ダメージ + 状態異常付与
      poison_damage = pot
      new_hp = [defender.current_hp - poison_damage, 0].max
      defender.update!(current_hp: new_hp)

      # 毒状態異常を付与（symbol で指定）
      defender.conditions.create!(
        condition_type: :poisoned, # symbol に変更
        duration: 1,
        is_active: true,
        effect_value: pot,
        origin_participant_id: attacker.id
      )

      log_event('POT対抗',
                "#{defender_char.name} のPOT対抗(#{roll}/#{success_rate}) → 失敗！ 毒ダメージ #{poison_damage} (HP: #{defender.current_hp + poison_damage} → #{new_hp})", character: defender_char)

      # 毒ダメージで戦闘不能
      if new_hp <= 0
        defender.update!(is_active: false)
        log_event('戦闘不能', "#{defender_char.name} は戦闘不能になった", character: defender_char)
      end
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

    # マーシャルアーツ判定
    if attack_method.can_apply_ma
      ma_skill = character.skills.find_by(name: 'マーシャルアーツ')
      if ma_skill
        ma_roll = rand(1..100)
        ma_critical = ma_roll <= 5
        ma_fumble = ma_roll >= 96
        ma_success = ma_roll <= ma_skill.success

        if ma_critical
          # クリティカル: ダメージ×4
          total *= 4
          log_event('マーシャルアーツ', "#{character.name} のマーシャルアーツ判定(#{ma_roll}) → クリティカル！ ダメージ×4", character: character)
        elsif ma_fumble
          # ファンブル: ダメージ半分
          total = (total / 2.0).round
          log_event('マーシャルアーツ', "#{character.name} のマーシャルアーツ判定(#{ma_roll}) → ファンブル！ ダメージ半分", character: character)
        elsif ma_success
          # 成功: ダメージ×2
          total *= 2
          log_event('マーシャルアーツ', "#{character.name} のマーシャルアーツ判定(#{ma_roll}) → 成功！ ダメージ×2", character: character)
        else
          # 失敗: 補正なし
          log_event('マーシャルアーツ', "#{character.name} のマーシャルアーツ判定(#{ma_roll}) → 失敗、補正なし", character: character)
        end
      end
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
        log_event('戦闘終了', "#{winner.character.name} の勝利！", character: winner.character)
      else
        first_char = @participants.first&.character
        log_event('戦闘終了', '全員戦闘不能', character: first_char)
      end

      return true
    end

    # チーム戦：1チームのみ残っているか
    if battle.battle_mode == 'team'
      active_teams = active.map(&:team_id).uniq
      if active_teams.size == 1
        battle.update!(is_finished: true)
        team_name = active.first.team.where_team
        log_event('戦闘終了', "チーム#{team_name} の勝利！", character: active.first.character)
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

  # ログ記録（character は optional）
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
