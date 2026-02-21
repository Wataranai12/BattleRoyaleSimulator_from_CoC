# frozen_string_literal: true

module CharacterParsers
  class BaseParser
    def initialize(text_data)
      @text = text_data
      # 改行コードを統一し、末尾空白を除去
      @lines = text_data.gsub(/\r\n?/, "\n").split("\n").map { |l| l.rstrip }
    end

    def parse
      raise NotImplementedError
    end

    private

    # セクション名を含む行から次のセクション見出し行までを返す
    # section_name は文字列または正規表現を受け付ける
    def find_section(section_name)
      pattern = section_name.is_a?(Regexp) ? section_name : Regexp.new(Regexp.escape(section_name))
      start_index = @lines.index { |l| l.match?(pattern) }
      return nil unless start_index

      end_index = @lines[(start_index + 1)..].index do |l|
        l.match?(/^[■【]/) && !l.match?(pattern)
      end

      if end_index
        @lines[start_index..(start_index + end_index)]
      else
        @lines[start_index..]
      end
    end

    # 数値をスキャンする際に全角数字も半角に変換する
    def normalize_numbers(str)
      str.tr('０-９', '0-9')
    end

    def determine_skill_category(skill_name)
      clean_name = skill_name.gsub(/[（）()【】]/, '').strip
      case clean_name
      when /回避/ then :dodge
      when /拳銃|ライフル|ショットガン|サブマシンガン|マシンガン|ナイフ|投擲|棍棒|剣|斧|鞭|チェーンソー|弓|火器/ then :attack
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

      normalized = damage_str.strip.downcase.gsub(/[\s　\u3000]/, '')
      return unless normalized.match?(/\d+d\d+/) || normalized == '0' || normalized == '特殊'

      normalized
    end
  end
end
