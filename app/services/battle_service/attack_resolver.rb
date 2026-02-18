# frozen_string_literal: true

module BattleService
  class AttackResolver
    def initialize(participants, log_callback)
      @participants = participants
      @log = log_callback
      @condition_manager = BattleService::ConditionManager.new(log_callback)
    end

    def resolve(attacker, defender)
      char = attacker.character
      grapple_condition  = attacker.conditions.find_by(condition_type: 'grappling', is_active: true)
      grappled_condition = attacker.conditions.find_by(condition_type: 'grappled',  is_active: true)

      return resolve_str_contest(attacker, grappled_condition) if grappled_condition

      attack_methods = char.attack_methods.includes(:skill, :default_condition)
      attack_methods = attack_methods.joins(:skill).where(skills: { category: 'grapple' }) if grapple_condition

      if attack_methods.empty?
        @log.call('エラー', "#{char.name} の攻撃手段がありません", character: char)
        return
      end

      attack_method = attack_methods.sample
      skill = attack_method.skill
      calculator = BattleService::DamageCalculator.new(char, @log)

      skill_success = apply_nerf_penalty(attacker, skill.success)
      roll = DiceRoller.percentile

      return resolve_fumble(attacker, char, attack_method, roll, calculator) if roll >= 96
      return @log.call('攻撃', "#{char.name} の #{attack_method.show_name}(#{roll}) → 失敗", character: char) if roll > skill_success

      if skill.category == 'grapple'
        resolve_grapple(attacker, defender, char, attack_method, roll, grapple_condition, calculator)
      elsif roll <= 5
        resolve_critical(attacker, defender, char, attack_method, roll, calculator)
      else
        resolve_normal(attacker, defender, char, attack_method, roll, calculator)
      end
    end

    def resolve_counter(attacker, defender)
      char = attacker.character
      attack_methods = char.attack_methods.includes(:skill)

      if attack_methods.empty?
        @log.call('エラー', "#{char.name} の攻撃手段がありません（反撃失敗）", character: char)
        return
      end

      attack_method = attack_methods.sample
      roll = DiceRoller.percentile

      unless roll <= attack_method.skill.success
        @log.call('反撃', "#{char.name} の反撃 #{attack_method.show_name}(#{roll}) → 失敗", character: char)
        return
      end

      damage = BattleService::DamageCalculator.new(char, @log).calculate(attack_method)
      apply_damage(defender, damage, char, attack_method, roll, '反撃')
    end

    private

    def resolve_fumble(attacker, char, attack_method, roll, calculator)
      new_hp = [attacker.current_hp - 1, 0].max
      attacker.update!(current_hp: new_hp)
      @condition_manager.apply_nerf(attacker)
      @log.call('ファンブル',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → ファンブル！ 自分に 1ダメージ、2ラウンド技能-20% (HP: #{attacker.current_hp + 1} → #{new_hp})",
                character: char)
      check_incapacitated(attacker, char) if new_hp <= 0
    end

    def resolve_critical(attacker, defender, char, attack_method, roll, calculator)
      damage = calculator.calculate(attack_method)
      new_hp = [defender.current_hp - damage, 0].max
      defender.update!(current_hp: new_hp)
      @log.call('クリティカル',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → クリティカル！ #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})",
                character: char, target: defender.character)

      try_poison(attacker, defender, attack_method)
      check_incapacitated(defender, defender.character) if new_hp <= 0
    end

    def resolve_normal(attacker, defender, char, attack_method, roll, calculator)
      dodge_skill = defender.character.skills.find_by(name: '回避')
      dodge_roll = DiceRoller.percentile

      if dodge_roll <= 5 && dodge_skill
        @log.call('回避',
                  "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避クリティカル(#{dodge_roll})！ 反撃発動",
                  character: char, target: defender.character)
        return resolve_counter(defender, attacker)
      end

      if dodge_roll >= 96
        damage = calculator.calculate(attack_method) * 2
        new_hp = [defender.current_hp - damage, 0].max
        defender.update!(current_hp: new_hp)
        @log.call('回避ファンブル',
                  "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避ファンブル(#{dodge_roll})！ #{damage}ダメージ (2倍) (HP: #{defender.current_hp + damage} → #{new_hp})",
                  character: char, target: defender.character)
        try_poison(attacker, defender, attack_method)
        check_incapacitated(defender, defender.character) if new_hp <= 0
        return
      end

      if dodge_skill && dodge_roll <= dodge_skill.success
        @log.call('攻撃', "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避成功(#{dodge_roll})",
                  character: char, target: defender.character)
        return
      end

      damage = calculator.calculate(attack_method)
      new_hp = [defender.current_hp - damage, 0].max
      defender.update!(current_hp: new_hp)
      @log.call('攻撃',
                "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})",
                character: char, target: defender.character)
      try_poison(attacker, defender, attack_method)
      check_incapacitated(defender, defender.character) if new_hp <= 0
    end

    def resolve_grapple(attacker, defender, char, attack_method, roll, grapple_condition, calculator)
      if grapple_condition
        damage = calculator.calculate_grapple
        new_hp = [defender.current_hp - damage, 0].max
        defender.update!(current_hp: new_hp)
        @log.call('組み付き',
                  "#{char.name} の絞め技 → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})",
                  character: char, target: defender.character)
        if new_hp <= 0
          defender.update!(is_active: false)
          @log.call('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)
          @condition_manager.release_grapple(attacker, defender)
        end
        return
      end

      # 新規組み付き：回避判定
      defender_grappled = defender.conditions.find_by(condition_type: 'grappled', is_active: true)
      unless defender_grappled
        dodge_skill = defender.character.skills.find_by(name: '回避')
        dodge_roll  = DiceRoller.percentile

        if dodge_roll <= 5 && dodge_skill
          @log.call('回避',
                    "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避クリティカル(#{dodge_roll})！ 反撃発動",
                    character: char, target: defender.character)
          return resolve_counter(defender, attacker)
        end

        if dodge_skill && dodge_roll <= dodge_skill.success
          @log.call('組み付き',
                    "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} 回避成功(#{dodge_roll})",
                    character: char, target: defender.character)
          return
        end
      end

      @condition_manager.apply_grapple(attacker, defender)
      @log.call('組み付き', "#{char.name} の #{attack_method.show_name}(#{roll}) → #{defender.character.name} を組み付いた！",
                character: char, target: defender.character)
    end

    def resolve_str_contest(grappled_participant, grappled_condition)
      grappled_char   = grappled_participant.character
      grappler        = @participants.find { |p| p.id == grappled_condition.origin_participant_id }

      unless grappler&.is_active
        grappled_condition.update!(is_active: false)
        @log.call('組み付き解除', "#{grappled_char.name} は組み付きから解放された（相手が戦闘不能）", character: grappled_char)
        return
      end

      grappled_str = grappled_char.characteristics.find_by(name: 'str')&.value || 10
      grappler_str = grappler.character.characteristics.find_by(name: 'str')&.value || 10
      success_rate = [[50 + (grappled_str - grappler_str) * 5, 5].max, 95].min
      roll = DiceRoller.percentile

      if roll <= success_rate
        grappled_condition.update!(is_active: false)
        grappler.conditions.find_by(condition_type: 'grappling', is_active: true)&.update!(is_active: false)
        @log.call('STR対抗', "#{grappled_char.name} のSTR対抗(#{roll}/#{success_rate}) → 成功！ 組み付きから脱出",
                  character: grappled_char)
      else
        @log.call('STR対抗', "#{grappled_char.name} のSTR対抗(#{roll}/#{success_rate}) → 失敗、組み付かれたまま",
                  character: grappled_char)
      end
    end

    def try_poison(attacker, defender, attack_method)
      default_condition = attack_method.default_condition
      return unless default_condition&.poisoned?

      @condition_manager.poison_check(attacker, defender, default_condition, @log)
    end

    def apply_damage(defender, damage, char, attack_method, roll, action_type)
      new_hp = [defender.current_hp - damage, 0].max
      defender.update!(current_hp: new_hp)
      @log.call(action_type,
                "#{char.name} の反撃 #{attack_method.show_name}(#{roll}) → #{defender.character.name} に #{damage}ダメージ (HP: #{defender.current_hp + damage} → #{new_hp})",
                character: char, target: defender.character)
      check_incapacitated(defender, defender.character) if new_hp <= 0
    end

    def check_incapacitated(participant, char)
      return if participant.is_active == false

      participant.update!(is_active: false)
      @log.call('戦闘不能', "#{char.name} は戦闘不能になった", character: char)
    end

    def apply_nerf_penalty(participant, base_success)
      nerf = participant.conditions.find_by(condition_type: 'nerf', is_active: true)
      nerf ? [base_success - 20, 0].max : base_success
    end
  end
end
