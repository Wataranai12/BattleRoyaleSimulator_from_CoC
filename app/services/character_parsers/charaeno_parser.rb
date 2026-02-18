# frozen_string_literal: true

module CharacterParsers
  class CharaenoParser < BaseParser
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
      first_line = @lines.first&.strip
      return nil unless first_line

      first_line.match(/^([^(（]+)/)&.then { |m| m[1].strip }
    end

    def extract_characteristics
      chars = {}

      ability_line = @lines.find { |l| l.match?(/STR:\d+/) }
      if ability_line
        %w[STR DEX INT CON APP POW SIZ EDU].each do |ability|
          if (match = ability_line.match(/#{ability}:(\d+)/))
            chars[ability.downcase.to_sym] = match[1].to_i
          end
        end
      end

      @lines.each do |line|
        chars[:hp]  = line.match(/耐久力[：:](\d+)/)[1].to_i           if line.match?(/耐久力[：:](\d+)/)
        chars[:mp]  = line.match(/マジック[・･]?ポイント[：:](\d+)/)[1].to_i if line.match?(/マジック[・･]?ポイント[：:](\d+)/)
        chars[:san] = line.match(/正気度[：:](\d+)/)[1].to_i            if line.match?(/正気度[：:](\d+)/)
      end

      chars
    end

    def extract_skills
      skills = []
      section = find_section('【技能】')
      return skills unless section

      section.each do |line|
        next unless (match = line.match(/^([^：:]+)[：:](\d+)%/))

        skill_name = match[1].strip
        success = match[2].to_i
        next if success.zero?

        skills << { name: skill_name, category: determine_skill_category(skill_name), success: success }
      end

      skills
    end

    def extract_weapons
      # Charaeno形式では武器が記載されていないことが多いため空配列を返す
      []
    end

    def extract_db
      db_line = @lines.find { |l| l.match?(/ダメージ[・･]?ボーナス[：:]/) }
      return '0' unless db_line

      db_line.match(/([+-]?\d+[dD]\d+|0)/)&.then { |m| m[1].upcase } || '0'
    end
  end
end
