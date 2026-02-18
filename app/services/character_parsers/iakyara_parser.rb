# frozen_string_literal: true

module CharacterParsers
  class IakyaraParser < BaseParser
    def parse
      {
        name: extract_name,
        characteristics: extract_characteristics,
        skills: extract_skills,
        attack_methods: extract_weapons,
        damage_bonus: extract_db
      }
    end

    private

    def extract_name
      section = find_section('【基本情報】')
      return nil unless section

      name_line = section.find { |l| l.match?(/^名前[：:\s]/) }
      return nil unless name_line

      name_line.match(/名前[：:\s]+([^(（]+)/)&.then { |m| m[1].strip }
    end

    def extract_characteristics
      chars = {}
      section = find_section('【能力値】')
      return chars unless section

      ability_names = %w[STR CON POW DEX APP SIZ INT EDU HP MP SAN IDE 幸運 知識]
      ability_names.each do |ability|
        line = section.find { |l| l.match?(/^\s*#{Regexp.escape(ability)}\s+\d+/) }
        next unless line

        value = line.scan(/\d+/).map(&:to_i).first
        next unless value

        key = case ability
              when 'IDE' then :idea
              when '幸運' then :luck
              when '知識' then :know
              else ability.downcase.to_sym
              end
        chars[key] = value
      end

      san_line = section.find { |l| l.match?(/現在SAN値/) }
      if san_line && (match = san_line.match(%r{(\d+)\s*/\s*(\d+)}))
        chars[:san] = match[1].to_i
      end

      chars
    end

    def extract_skills
      skills = []
      section = find_section('【技能値】')
      return skills unless section

      section.each do |line|
        next unless line.match?(/^[ぁ-んァ-ヶー一-龠々（）()]+/)
        next unless (match = line.match(/^([ぁ-んァ-ヶー一-龠々（）()]+)\s+(\d+)/))

        skill_name = match[1].strip.gsub(/[（）()]/, '')
        success = match[2].to_i
        next if success.zero?

        skills << { name: skill_name, category: determine_skill_category(skill_name), success: success }
      end

      skills
    end

    def extract_weapons
      weapons = []
      section = find_section('【戦闘・武器・防具】')
      return weapons unless section

      header_index = section.index { |l| l.match?(/名前\s+成功率\s+ダメージ/) }
      return weapons unless header_index

      section[(header_index + 1)..].each do |line|
        next if line.strip.empty?
        next if line.match?(/^【/)

        parts = line.split(/\s{2,}/)
        weapon_name = parts[0]&.strip
        next if weapon_name.nil? || weapon_name.empty?

        weapons << {
          skill_name: extract_weapon_skill_name(weapon_name),
          show_name: weapon_name,
          weapon_name: weapon_name,
          base_damage: normalize_damage_formula(parts[1]&.strip) || '1d3',
          can_apply_db: can_apply_damage_bonus?(weapon_name),
          can_apply_ma: false,
          range: parts[2]&.strip
        }
      end

      weapons
    end

    def extract_db
      db_line = @lines.find { |l| l.match?(/^DB\s+/) }
      return '0' unless db_line

      db_line.match(/([+-]?\d+[dD]\d+|0)/)&.then { |m| m[1].upcase } || '0'
    end
  end
end
