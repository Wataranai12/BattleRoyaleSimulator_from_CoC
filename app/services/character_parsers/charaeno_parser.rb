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
      # 1行目が「名前 (読み) (年齢) 職業 性別」の形式
      first_line = @lines.first&.strip
      return nil unless first_line

      # 括弧・スペースより前の名前部分を取得
      m = first_line.match(/^([^(（\t]+)/)
      m ? m[1].strip : first_line
    end

    def extract_characteristics
      chars = {}

      # 「STR:16\tDEX:11...」のような1行または複数行にわたる能力値行を探す
      # STR・DEXの両方がある行 or 個別行に対応
      ability_line = @lines.find { |l| l.match?(/STR[:：]\d+/) }
      if ability_line
        %w[STR DEX INT CON APP POW SIZ EDU].each do |ability|
          # 複数行に分かれている場合も考慮して全行から検索
          @lines.each do |line|
            if (m = line.match(/#{ability}[:：](\d+)/))
              chars[ability.downcase.to_sym] = m[1].to_i
              break
            end
          end
        end
      end

      # HP/MP/SAN は専用行から取得（各種表記に対応）
      @lines.each do |line|
        chars[:hp]  = line.match(/耐久力[：:](\d+)/)[1].to_i           if line.match?(/耐久力[：:](\d+)/)
        chars[:mp]  = line.match(/マジック[・･]?ポイント[：:](\d+)/)[1].to_i if line.match?(/マジック[・･]?ポイント[：:](\d+)/)
        # 「正気度：65」または「SAN:65」形式
        if line.match?(/^正気度[：:](\d+)/)
          chars[:san] = line.match(/正気度[：:](\d+)/)[1].to_i
        elsif line.match?(/^SAN[:：](\d+)/) && !chars[:san]
          chars[:san] = line.match(/SAN[:：](\d+)/)[1].to_i
        end
      end

      chars
    end

    def extract_skills
      skills = []
      section = find_section('【技能】')
      return skills unless section

      section.each do |line|
        # 「スキル名：80%」形式
        next unless (match = line.match(/^([^：:]+)[：:](\d+)%/))

        skill_name = match[1].strip
        success = match[2].to_i
        next if skill_name.empty? || success.zero?

        skills << { name: skill_name, category: determine_skill_category(skill_name), success: success }
      end

      # 【火器】【近接戦】などのサブセクションにある技能も取得
      %w[火器 近接戦 射撃 格闘].each do |sub|
        sub_section = find_section("【#{sub}】")
        next unless sub_section

        sub_section.each do |line|
          next unless (match = line.match(/^([^：:]+)[：:](\d+)%/))

          skill_name = match[1].strip
          success = match[2].to_i
          next if skill_name.empty? || success.zero?
          next if skills.any? { |s| s[:name] == skill_name }

          skills << { name: skill_name, category: determine_skill_category(skill_name), success: success }
        end
      end

      skills
    end

    def extract_weapons
      weapons = []
      section = find_section('【武器】')
      return weapons unless section

      section.each do |line|
        next if line.strip.empty? || line.match?(/^【/)

        # 「キック：-% 1D6+DB (射程:タッチ, 攻撃回数:1, 装弾数:-, 故障:-)」形式
        # 武器名を取得
        next unless (name_match = line.match(/^(.+?)[：:]/))

        weapon_name = name_match[1].strip
        next if weapon_name.empty?

        # ダメージ式を取得: +DB / +db は除去し、ダイス式部分のみ残す
        # 例: "1D6+DB" → "1d6", "1D3+1D4" → "1d3+1d4"
        damage_raw = line.match(/(\d+[dD]\d+(?:[+\-]\d+[dD]\d+)*(?:[+\-]\d+)?)(?:\+DB|\+db)?/)&.[](1)
        can_db = can_apply_damage_bonus?(weapon_name) || line.match?(/\+DB|\+db/i)

        # 射程を括弧内から取得
        range_info = line.match(/射程[：:]([^,)]+)/)&.[](1)&.strip

        weapons << {
          skill_name: extract_weapon_skill_name(weapon_name),
          show_name: weapon_name,
          weapon_name: weapon_name,
          base_damage: normalize_damage_formula(damage_raw) || '1d3',
          can_apply_db: can_db,
          can_apply_ma: false,
          range: range_info
        }
      end

      weapons
    end

    def extract_db
      db_line = @lines.find { |l| l.match?(/ダメージ[・･]?ボーナス[：:]/) }
      return '0' unless db_line

      db_line.match(/([+-]?\d+[dD]\d+|[+-]?\d+)/)&.then do |m|
        val = m[1].upcase
        val.match?(/^[+-]/) ? val : "+#{val}"
      end || '0'
    end
  end
end
