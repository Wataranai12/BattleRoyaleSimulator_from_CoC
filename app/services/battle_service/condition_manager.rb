# frozen_string_literal: true

module BattleService
  class ConditionManager
    def initialize(log_callback)
      @log = log_callback
    end

    # ラウンド開始時のduration減少・解除
    def tick_conditions(participant)
      participant.conditions.where(is_active: true).each do |condition|
        next unless condition.duration.present?

        condition.decrement!(:duration)
        if condition.duration <= 0
          condition.update!(is_active: false)
          @log.call('状態異常解除', "#{participant.character.name} の #{condition.condition_type} が解除された",
                    character: participant.character)
        end
      end
    end

    # 組み付き付与
    def apply_grapple(attacker, defender)
      attacker.conditions.create!(condition_type: 'grappling', duration: nil, is_active: true, origin_participant_id: defender.id)
      defender.conditions.create!(condition_type: 'grappled',  duration: nil, is_active: true, origin_participant_id: attacker.id)
    end

    # 組み付き解除
    def release_grapple(attacker, defender)
      attacker.conditions.find_by(condition_type: 'grappling', is_active: true)&.update!(is_active: false)
      defender.conditions.find_by(condition_type: 'grappled',  is_active: true)&.update!(is_active: false)
    end

    # nerf付与
    def apply_nerf(participant)
      participant.conditions.create!(condition_type: 'nerf', duration: 2, is_active: true, effect_value: -20)
    end

    # 毒付与
    def apply_poison(attacker, defender, pot)
      defender.conditions.create!(
        condition_type: :poisoned,
        duration: 1,
        is_active: true,
        effect_value: pot,
        origin_participant_id: attacker.id
      )
    end

    # POT対抗判定
    def poison_check(attacker, defender, default_condition, log_callback)
      pot = default_condition.effect_value || 10
      con = defender.character.characteristics.find_by(name: 'con')&.value || 10
      success_rate = [[50 + (con - pot), 5].max, 95].min
      roll = DiceRoller.percentile

      if roll <= success_rate
        log_callback.call('POT対抗', "#{defender.character.name} のPOT対抗(#{roll}/#{success_rate}) → 成功！ 毒無効",
                          character: defender.character)
      else
        poison_damage = pot
        new_hp = [defender.current_hp - poison_damage, 0].max
        defender.update!(current_hp: new_hp)
        apply_poison(attacker, defender, pot)
        log_callback.call('POT対抗',
                          "#{defender.character.name} のPOT対抗(#{roll}/#{success_rate}) → 失敗！ 毒ダメージ #{poison_damage} (HP: #{defender.current_hp + poison_damage} → #{new_hp})",
                          character: defender.character)

        if new_hp <= 0
          defender.update!(is_active: false)
          log_callback.call('戦闘不能', "#{defender.character.name} は戦闘不能になった", character: defender.character)
        end
      end
    end
  end
end
