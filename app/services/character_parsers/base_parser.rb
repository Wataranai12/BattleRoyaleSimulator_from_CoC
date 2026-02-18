# frozen_string_literal: true

module CharacterParsers
  class BaseParser
    def initialize(text_data)
      @text = text_data
      @lines = text_data.split("\n")
    end

    def parse
      raise NotImplementedError
    end

    private

    def find_section(section_name)
      start_index = @lines.index { |l| l.include?(section_name) }
      return nil unless start_index

      end_index = @lines[(start_index + 1)..].index do |l|
        l.match?(/^[■【]/) && !l.include?(section_name)
      end

      if end_index
        @lines[start_index..(start_index + end_index)]
      else
        @lines[start_index..]
      end
    end

    def determine_skill_category(skill_name)
      clean_name = skill_name.gsub(/[（）()]/, '').strip
      case clean_name
      when /回避/ then :dodge
      when /拳銃|ライフル|ショットガン|サブマシンガン|マシンガン|ナイフ|投擲|棍棒|剣|斧|鞭|チェーンソー|弓/ then :attack
      when /こぶし|パンチ|キック|頭突き|マーシャルアーツ/ then :martialarts
      when /組み付き|組みつき/ then :grapple
      else :other
      end
    end

    def extract_weapon_skill_name(weapon_name)
      clean_name = weapon_name.gsub(/[（）()]/, '').strip
      case clean_name
      when /ナイフ/ then 'ナイフ'
      when /拳銃/ then '拳銃'
      when /ライフル/ then 'ライフル'
      when /ショットガン/ then 'ショットガン'
      when /サブマシンガン/ then 'サブマシンガン'
      when /こぶし|パンチ/ then 'こぶし'
      when /キック/ then 'キック'
      else clean_name
      end
    end

    def can_apply_damage_bonus?(weapon_name)
      weapon_name.match?(/ナイフ|こぶし|パンチ|キック|頭突き|棍棒|剣|斧|鞭|チェーンソー|マーシャルアーツ/)
    end

    def normalize_damage_formula(damage_str)
      return nil if damage_str.nil? || damage_str.strip.empty?

      normalized = damage_str.strip.downcase.gsub(/\s+/, '')
      return unless normalized.match?(/\d+d\d+/) || normalized == '0' || normalized == '特殊'

      normalized
    end
  end
end
