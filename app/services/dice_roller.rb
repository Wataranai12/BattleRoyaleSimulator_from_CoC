# frozen_string_literal: true

class DiceRoller
  # "1d10", "1d6+1d4", "1d3+2" などを解析してロール
  def self.roll(formula)
    return 0 if formula.blank?

    total = 0

    # "1d10+1d4+2" → ["1d10", "1d4", "2"]
    parts = formula.gsub(/\s+/, '').split(/([+-])/)
    operator = '+'

    parts.each do |part|
      case part
      when '+', '-'
        operator = part
      when /\d+d\d+/i
        # ダイスロール
        dice_count, dice_sides = part.downcase.split('d').map(&:to_i)
        roll_result = dice_count.times.map { rand(1..dice_sides) }.sum
        total = operator == '+' ? total + roll_result : total - roll_result
      when /\d+/
        # 固定値
        value = part.to_i
        total = operator == '+' ? total + value : total - value
      end
    end

    [total, 0].max # 最低0
  end
end
