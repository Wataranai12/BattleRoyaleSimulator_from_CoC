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
      # 「タイトル：〇〇」行から取得。括弧付き読み仮名は除去。
      title_line = @lines.find { |l| l.match?(/^タイトル[：:]\s*\S/) }
      if title_line
        # 括弧の手前まで、または行末まで
        m = title_line.match(/[：:]([^(（\r\n]+)/)
        return m[1].strip if m
      end

      # フォールバック: 「キャラクター名：〇〇」行から取得
      char_name_line = @lines.find { |l| l.match?(/^キャラクター名[：:]/) }
      if char_name_line
        m = char_name_line.match(/[：:]([^(（\r\n]+)/)
        return m[1].strip if m
      end

      nil
    end

    def extract_characteristics
      chars = {}
      section = find_section('■能力値■')
      return chars unless section

      # セクション内全行を対象に HP / MP / SAN を探す（位置が変動しても対応）
      section.each do |line|
        chars[:hp]  = line.match(/HP[：:](\d+)/)[1].to_i  if line.match?(/HP[：:](\d+)/)
        chars[:mp]  = line.match(/MP[：:](\d+)/)[1].to_i  if line.match?(/MP[：:](\d+)/)
        # SAN：62/99 のようなスラッシュ付きも考慮し、現在値（最初の数値）を取得
        if line.match?(/SAN[：:]\d+/)
          chars[:san] = line.match(/SAN[：:](\d+)/)[1].to_i
        end
      end

      # =合計= 行から8つの基本能力値を取得
      total_line = section.find { |l| l.match?(/=合計=/) }
      if total_line
        # 全角スペースも含めて数値のみを抽出
        numbers = normalize_numbers(total_line).scan(/\d+/).map(&:to_i)
        %i[str con pow dex app siz int edu].each_with_index do |name, i|
          chars[name] = numbers[i] if numbers[i]
        end
        # =合計= 行末のHP/MPで上書き（より正確な値）
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
        # 1行に複数スキルが並ぶ形式に対応: 《スキル名》数値％ を全て抽出
        line.scan(/《(.+?)》[\s　]*(\d+)％/) do |skill_name, value|
          skill_name = skill_name.strip
          # 空スキル・値0・カッコのみは除外
          next if skill_name.empty? || value.to_i.zero?
          # 括弧内の補足（例: こぶし（パンチ）→ こぶし）は category 判定用に残しつつ登録
          skills << {
            name: skill_name,
            category: determine_skill_category(skill_name),
            success: value.to_i
          }
        end
      end

      skills
    end

    def extract_weapons
      weapons = []
      section = find_section('■戦闘■')
      return weapons unless section

      header_index = section.index { |l| l.match?(/名称[\s　]+成功率[\s　]+ダメージ/) }
      return weapons unless header_index

      section[(header_index + 1)..].each do |line|
        break if line.match?(/^■/)
        next if line.strip.empty?
        # スラッシュのみの区切り行をスキップ
        next if line.match?(%r{^\s*/\s*$})

        parts = line.split(/\t+|[ 　]{2,}/)
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
      # 「ダメージボーナス：1d4」など各種表記に対応
      db_line = @lines.find { |l| l.match?(/ダメージ[・･]?ボーナス[：:]/) }
      return '0' unless db_line

      db_line.match(/([+-]?\d+[dD]\d+|[+-]?\d+)/)&.then do |m|
        val = m[1].upcase
        # 符号なし（例: 1D4）は + を補完して +1D4 に統一する
        val.match?(/^[+-]/) ? val : "+#{val}"
      end || '0'
    end
  end
end
