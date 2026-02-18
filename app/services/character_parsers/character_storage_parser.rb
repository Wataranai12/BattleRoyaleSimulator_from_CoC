# frozen_string_literal: true

module CharacterParsers
  class CharacterStorageParser < BaseParser
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
      title_line = @lines.find { |l| l.match?(/^タイトル[：:]/) }
      return nil unless title_line

      if (match = title_line.match(/[：:](.+?)[(（]/))
        match[1].strip
      elsif (match = title_line.match(/[：:](.+)$/))
        match[1].strip
      end
    end

    def extract_characteristics
      chars = {}
      section = find_section('■能力値■')
      return chars unless section

      # HP / MP / SAN を上部から取得
      section.first(5).each do |line|
        chars[:hp]  = line.match(/HP[：:](\d+)/)[1].to_i  if line.match?(/HP[：:](\d+)/)
        chars[:mp]  = line.match(/MP[：:](\d+)/)[1].to_i  if line.match?(/MP[：:](\d+)/)
        chars[:san] = line.match(/SAN[：:](\d+)/)[1].to_i if line.match?(/SAN[：:](\d+)/)
      end

      # =合計= 行から能力値を取得
      total_line = section.find { |l| l.match?(/=合計=/) }
      if total_line
        numbers = total_line.scan(/\d+/).map(&:to_i)
        %i[str con pow dex app siz int edu].each_with_index do |name, i|
          chars[name] = numbers[i] if numbers[i]
        end
        chars[:hp] = numbers[8] if numbers[8]&.positive?
        chars[:mp] = numbers[9] if numbers[9]&.positive?
      end

      chars
    end

    def extract_skills
      skills = []
      section = find_section('■技能■')
      return skills unless section

      section.each do |line|
        next unless (match = line.match(/[●　\s]*《(.+?)》[　\s]*(\d+)％/))

        skill_name = match[1].strip
        success = match[2].to_i
        next if success.zero?

        skills << { name: skill_name, category: determine_skill_category(skill_name), success: success }
      end

      skills
    end

    def extract_weapons
      weapons = []
      section = find_section('■戦闘■')
      return weapons unless section

      header_index = section.index { |l| l.match?(/名称\s+成功率\s+ダメージ/) }
      return weapons unless header_index

      section[(header_index + 1)..].each do |line|
        break if line.match?(/^■/)
        next if line.strip.empty?
        next if line.match?(%r{^\s*/})

        parts = line.split(/\t+|\s{2,}/)
        weapon_name = parts[0]&.strip
        next if weapon_name.nil? || weapon_name.empty?

        weapons << {
          skill_name: extract_weapon_skill_name(weapon_name),
          show_name: weapon_name,
          weapon_name: weapon_name,
          base_damage: normalize_damage_formula(parts[2]&.strip) || '1d3',
          can_apply_db: can_apply_damage_bonus?(weapon_name),
          can_apply_ma: false,
          range: parts[3]&.strip
        }
      end

      weapons
    end

    def extract_db
      db_line = @lines.find { |l| l.match?(/ダメージボーナス[：:]/) }
      return '0' unless db_line

      db_line.match(/([+-]?\d+[dD]\d+|0)/)&.then { |m| m[1].upcase } || '0'
    end
  end
end
