# frozen_string_literal: true

module BattleService
  class DamageCalculator
    def initialize(character, log_callback)
      @character = character
      @log = log_callback
    end

    def calculate(attack_method)
      total = DiceRoller.roll(attack_method.base_damage)
      total += damage_bonus if attack_method.can_apply_db
      total = apply_martial_arts(total, attack_method) if attack_method.can_apply_ma
      [total, 0].max
    end

    def calculate_grapple
      total = DiceRoller.roll('1d6')
      total += damage_bonus
      [total, 0].max
    end

    def damage_bonus
      return 0 if @character.damage_bonus.blank? || @character.damage_bonus == '0'

      DiceRoller.roll(@character.damage_bonus)
    end

    private

    def apply_martial_arts(total, attack_method)
      ma_skill = @character.skills.find_by(name: 'マーシャルアーツ')
      return total unless ma_skill

      roll = DiceRoller.percentile

      if roll <= 5
        @log.call('マーシャルアーツ', "#{@character.name} のマーシャルアーツ判定(#{roll}) → クリティカル！ ダメージ×4", character: @character)
        total * 4
      elsif roll >= 96
        @log.call('マーシャルアーツ', "#{@character.name} のマーシャルアーツ判定(#{roll}) → ファンブル！ ダメージ半分", character: @character)
        (total / 2.0).round
      elsif roll <= ma_skill.success
        @log.call('マーシャルアーツ', "#{@character.name} のマーシャルアーツ判定(#{roll}) → 成功！ ダメージ×2", character: @character)
        total * 2
      else
        @log.call('マーシャルアーツ', "#{@character.name} のマーシャルアーツ判定(#{roll}) → 失敗、補正なし", character: @character)
        total
      end
    end
  end
end
