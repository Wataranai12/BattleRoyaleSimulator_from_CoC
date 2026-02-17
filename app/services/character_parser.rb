# frozen_string_literal: true

# app/services/character_parser.rb
# 3つのフォーマット（いあきゃら、Charaeno、キャラクター保管所）に対応した汎用パーサー

class CharacterParser
  class ParseError < StandardError; end

  FORMATS = {
    iakyara: 'いあきゃら',
    charaeno: 'Charaeno',
    character_storage: 'キャラクター保管所'
  }.freeze

  def initialize(text_data)
    @text = text_data
    @lines = text_data.split("\n")
    @format = detect_format
  end

  def parse
    case @format
    when :iakyara
      parse_iakyara
    when :charaeno
      parse_charaeno
    when :character_storage
      parse_character_storage
    else
      raise ParseError, "未対応のフォーマットです。対応フォーマット: #{FORMATS.values.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error("Character parsing failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise ParseError, "データの解析に失敗しました: #{e.message}"
  end

  def parse_and_create_character(user)
    data = parse

    character = Character.new(
      user: user,
      name: data[:name],
      damage_bonus: data[:damage_bonus],
      original_data: @text,
      data_source: FORMATS[@format]
    )

    # 能力値を作成
    data[:characteristics].each do |name, value|
      next if value.nil? || value.zero?

      character.characteristics.build(name: name.to_s, value: value)
    end

    # 技能を作成（初期値と同じ、または0の場合はスキップ）
    data[:skills].each do |skill_data|
      skill_name = skill_data[:name]
      success = skill_data[:success]

      next if success.nil? || success <= 0

      # 初期値チェック（後でバリデーションでも確認）
      default_value = Skill.default_value_for(skill_name, character)
      next if success == default_value

      character.skills.build(
        name: skill_name,
        category: skill_data[:category],
        success: success
      )
    end

    # 攻撃手段を作成
    data[:attack_methods].each do |method_data|
      # 常に利用可能な初期値技能はスキップ
      next if Skill.always_available_skills.include?(method_data[:weapon_name])

      # 対応する技能を探す
      character.skills.find { |s| s.name == method_data[:skill_name] }

      # 技能がない場合は仮の技能IDとしてnilを設定（後で関連付け）
      character.attack_methods.build(
        show_name: method_data[:show_name],
        weapon_name: method_data[:weapon_name],
        base_damage: method_data[:base_damage] || '1d3',
        can_apply_db: method_data[:can_apply_db] || false,
        can_apply_ma: method_data[:can_apply_ma] || false,
        range: method_data[:range],
        attacks_per_round: method_data[:attacks_per_round] || 1
      )
    end

    character
  end

  private

  #===========================================================================
  # フォーマット判定
  #===========================================================================
  def detect_format
    # 先頭から10行程度をチェック
    check_lines = @lines.first(10).map(&:strip).join("\n")

    # いあきゃら判定
    return :iakyara if check_lines.match?(/いあきゃらテキスト\s*6版/)

    # キャラクター保管所判定
    return :character_storage if @lines.first&.match?(/^タイトル[：:]/)

    # Charaeno判定（STR: DEX: INT:のパターン）
    return :charaeno if check_lines.match?(/STR:\d+\s+DEX:\d+\s+INT:\d+/)

    # より詳細な判定
    return :iakyara if @text.match?(/【能力値】/) && @text.match?(/【技能値】/)

    return :character_storage if @text.match?(/■能力値■/) && @text.match?(/■技能■/)

    return :charaeno if @text.match?(/耐久力[：:]/) && @text.match?(/マジック[・･]ポイント[：:]/)

    nil
  end

  #===========================================================================
  # いあきゃら形式のパース
  #===========================================================================
  def parse_iakyara
    {
      name: extract_iakyara_name,
      characteristics: extract_iakyara_characteristics,
      skills: extract_iakyara_skills,
      attack_methods: extract_iakyara_weapons,
      damage_bonus: extract_iakyara_db
    }
  end

  def extract_iakyara_name
    # 【基本情報】セクションから名前を抽出
    section = find_section('【基本情報】')
    return nil unless section

    name_line = section.find { |l| l.match?(/^名前[：:\s]/) }
    return nil unless name_line

    # "名前: 柊木　獅子 (ｸﾉｷﾞ ｼｼ)" から名前部分を抽出
    if (match = name_line.match(/名前[：:\s]+([^(（]+)/))
      match[1].strip
    end
  end

  def extract_iakyara_characteristics
    chars = {}

    # 【能力値】セクションを探す
    section = find_section('【能力値】')
    return chars unless section

    # 能力値名のリスト
    ability_names = %w[STR CON POW DEX APP SIZ INT EDU HP MP SAN IDE 幸運 知識]

    ability_names.each do |ability|
      # 能力値行を探す: "STR         15      15       0       0"
      line = section.find { |l| l.match?(/^\s*#{Regexp.escape(ability)}\s+\d+/) }
      next unless line

      # 数値を全て抽出
      numbers = line.scan(/\d+/).map(&:to_i)
      next if numbers.empty?

      # 最初の数値が「現在値」
      value = numbers.first

      # マッピング
      key = case ability
            when 'IDE' then :idea
            when '幸運' then :luck
            when '知識' then :know
            else ability.downcase.to_sym
            end

      chars[key] = value
    end

    # SAN値の特殊処理（"現在SAN値 50 / 99"のような形式）
    san_line = section.find { |l| l.match?(/現在SAN値/) }
    if san_line && (match = san_line.match(%r{(\d+)\s*/\s*(\d+)}))
      chars[:san] = match[1].to_i
    end

    chars
  end

  def extract_iakyara_skills
    skills = []

    # 【技能値】セクションを探す
    section = find_section('【技能値】')
    return skills unless section

    section.each do |line|
      # 技能行のパターン: "回避                      89      34       0      55       0       0"
      # または空白区切りの可能性もある

      # 技能名を検出（日本語で始まる）
      next unless line.match?(/^[ぁ-んァ-ヶー一-龠々（）()]+/)

      # 技能名と数値を抽出
      next unless (match = line.match(/^([ぁ-んァ-ヶー一-龠々（）()]+)\s+(\d+)/))

      skill_name = match[1].strip.gsub(/[（）()]/, '') # 括弧を除去
      success = match[2].to_i

      # 0%の技能はスキップ
      next if success.zero?

      skills << {
        name: skill_name,
        category: determine_skill_category(skill_name),
        success: success
      }
    end

    skills
  end

  def extract_iakyara_weapons
    weapons = []

    # 【戦闘・武器・防具】セクションを探す
    section = find_section('【戦闘・武器・防具】')
    return weapons unless section

    # ヘッダー行を探す
    header_index = section.index { |l| l.match?(/名前\s+成功率\s+ダメージ/) }
    return weapons unless header_index

    # ヘッダーの次の行から武器データを解析
    section[(header_index + 1)..].each do |line|
      next if line.strip.empty?
      next if line.match?(/^【/) # 次のセクション

      # 武器データを抽出
      # "ファイティング・ナイフ                   1d4+2+1d4        タッチ"
      parts = line.split(/\s{2,}/) # 2つ以上の連続した空白で分割

      weapon_name = parts[0]&.strip
      next if weapon_name.nil? || weapon_name.empty?

      damage = parts[1]&.strip
      range_str = parts[2]&.strip

      # ダメージ式の正規化
      damage = normalize_damage_formula(damage) if damage

      weapons << {
        skill_name: extract_weapon_skill_name(weapon_name),
        show_name: weapon_name,
        weapon_name: weapon_name,
        base_damage: damage || '1d3',
        can_apply_db: can_apply_damage_bonus?(weapon_name),
        can_apply_ma: false,
        range: range_str
      }
    end

    weapons
  end

  def extract_iakyara_db
    # DB行を探す: "DB +1D4"
    db_line = @lines.find { |l| l.match?(/^DB\s+/) }
    return '0' unless db_line

    if (match = db_line.match(/([+-]?\d+[dD]\d+|0)/))
      match[1].upcase # 統一のため大文字化
    else
      '0'
    end
  end

  #===========================================================================
  # Charaeno形式のパース
  #===========================================================================
  def parse_charaeno
    {
      name: extract_charaeno_name,
      characteristics: extract_charaeno_characteristics,
      skills: extract_charaeno_skills,
      attack_methods: extract_charaeno_weapons,
      damage_bonus: extract_charaeno_db
    }
  end

  def extract_charaeno_name
    # 最初の行: "目伯　晴告(ﾒｼﾞﾛﾊﾙﾂｸﾞ) (25)  ホールスタッフ兼殺し屋 男"
    first_line = @lines.first&.strip
    return nil unless first_line

    # 名前部分を抽出（括弧の前まで）
    if (match = first_line.match(/^([^(（]+)/))
      match[1].strip
    end
  end

  def extract_charaeno_characteristics
    chars = {}

    # 能力値行を探す: "STR:11 DEX:14 INT:16"
    ability_line = @lines.find { |l| l.match?(/STR:\d+/) }

    if ability_line
      %w[STR DEX INT CON APP POW SIZ EDU].each do |ability|
        if (match = ability_line.match(/#{ability}:(\d+)/))
          chars[ability.downcase.to_sym] = match[1].to_i
        end
      end
    end

    # 別の行にある可能性も考慮
    @lines.each do |line|
      # 耐久力
      if (match = line.match(/耐久力[：:](\d+)/))
        chars[:hp] = match[1].to_i
      end

      # マジック・ポイント
      if (match = line.match(/マジック[・･]?ポイント[：:](\d+)/))
        chars[:mp] = match[1].to_i
      end

      # 正気度
      if (match = line.match(/正気度[：:](\d+)/))
        chars[:san] = match[1].to_i
      end
    end

    chars
  end

  def extract_charaeno_skills
    skills = []

    # 【技能】セクションを探す
    section = find_section('【技能】')
    return skills unless section

    section.each do |line|
      # パターン: "医学：80%" または "回避：58%"
      next unless (match = line.match(/^([^：:]+)[：:](\d+)%/))

      skill_name = match[1].strip
      success = match[2].to_i

      # 0%はスキップ
      next if success.zero?

      skills << {
        name: skill_name,
        category: determine_skill_category(skill_name),
        success: success
      }
    end

    skills
  end

  def extract_charaeno_weapons
    weapons = []

    # 【武器】セクションを探す
    section = find_section('【武器】')
    return weapons unless section

    # Charaeno形式では武器が記載されていないことが多い
    # 技能から推測して仮の武器を作成
    # 例: ナイフ技能があれば、ナイフを武器として追加

    weapons
  end

  def extract_charaeno_db
    # ダメージ・ボーナス行を探す
    db_line = @lines.find { |l| l.match?(/ダメージ[・･]?ボーナス[：:]/) }
    return '0' unless db_line

    if (match = db_line.match(/([+-]?\d+[dD]\d+|0)/))
      match[1].upcase
    else
      '0'
    end
  end

  #===========================================================================
  # キャラクター保管所形式のパース
  #===========================================================================
  def parse_character_storage
    {
      name: extract_storage_name,
      characteristics: extract_storage_characteristics,
      skills: extract_storage_skills,
      attack_methods: extract_storage_weapons,
      damage_bonus: extract_storage_db
    }
  end

  def extract_storage_name
    # タイトル行: "タイトル：神崎　晄(カンザキミツル)"
    title_line = @lines.find { |l| l.match?(/^タイトル[：:]/) }
    return nil unless title_line

    # 括弧の前までを取得
    if (match = title_line.match(/[：:](.+?)[(（]/))
      match[1].strip
    elsif (match = title_line.match(/[：:](.+)$/))
      match[1].strip
    end
  end

  def extract_storage_characteristics
    chars = {}

    # ■能力値■セクションを探す
    section = find_section('■能力値■')
    return chars unless section

    # HP、MP、SANを先に取得（セクションの上部にある）
    section.first(5).each do |line|
      if (match = line.match(/HP[：:](\d+)/))
        chars[:hp] = match[1].to_i
      end
      if (match = line.match(/MP[：:](\d+)/))
        chars[:mp] = match[1].to_i
      end
      if (match = line.match(/SAN[：:](\d+)/))
        chars[:san] = match[1].to_i
      end
    end

    # =合計= 行を探す
    total_line = section.find { |l| l.match?(/=合計=/) }

    if total_line
      # 数値を抽出
      numbers = total_line.scan(/\d+/).map(&:to_i)

      # 順序: STR CON POW DEX APP SIZ INT EDU HP MP
      ability_names = %i[str con pow dex app siz int edu]

      ability_names.each_with_index do |name, index|
        chars[name] = numbers[index] if numbers[index]
      end

      # テーブルのHP、MPがあれば上書き
      chars[:hp] = numbers[8] if numbers[8]&.positive?
      chars[:mp] = numbers[9] if numbers[9]&.positive?
    end

    chars
  end

  def extract_storage_skills
    skills = []

    # ■技能■セクションを探す
    section = find_section('■技能■')
    return skills unless section

    section.each do |line|
      # パターン: "《回避》26％" または "●《拳銃》50％"
      next unless (match = line.match(/[●　\s]*《(.+?)》[　\s]*(\d+)％/))

      skill_name = match[1].strip
      success = match[2].to_i

      # 0%はスキップ
      next if success.zero?

      skills << {
        name: skill_name,
        category: determine_skill_category(skill_name),
        success: success
      }
    end

    skills
  end

  def extract_storage_weapons
    weapons = []

    # ■戦闘■セクションを探す
    section = find_section('■戦闘■')
    return weapons unless section

    # ヘッダー行を探す
    header_index = section.index { |l| l.match?(/名称\s+成功率\s+ダメージ/) }
    return weapons unless header_index

    # ヘッダーの次の行から武器データを解析
    section[(header_index + 1)..].each do |line|
      break if line.match?(/^■/) # 次のセクション
      next if line.strip.empty?
      next if line.match?(%r{^\s*/}) # 備考行

      # タブまたは複数の空白で分割
      parts = line.split(/\t+|\s{2,}/)

      weapon_name = parts[0]&.strip
      next if weapon_name.nil? || weapon_name.empty?

      # 成功率（使わないかもしれないが一応取得）
      # success_rate = parts[1]&.strip

      damage = parts[2]&.strip
      range_str = parts[3]&.strip

      weapons << {
        skill_name: extract_weapon_skill_name(weapon_name),
        show_name: weapon_name,
        weapon_name: weapon_name,
        base_damage: normalize_damage_formula(damage) || '1d3',
        can_apply_db: can_apply_damage_bonus?(weapon_name),
        can_apply_ma: false,
        range: range_str
      }
    end

    weapons
  end

  def extract_storage_db
    # ダメージボーナス行を探す
    db_line = @lines.find { |l| l.match?(/ダメージボーナス[：:]/) }
    return '0' unless db_line

    if (match = db_line.match(/([+-]?\d+[dD]\d+|0)/))
      match[1].upcase
    else
      '0'
    end
  end

  #===========================================================================
  # 共通ヘルパーメソッド
  #===========================================================================

  # セクションを抽出するヘルパー
  def find_section(section_name)
    start_index = @lines.index { |l| l.include?(section_name) }
    return nil unless start_index

    # 次のセクションまたはファイル終端までを取得
    end_index = @lines[(start_index + 1)..].index do |l|
      l.match?(/^[■【]/) && !l.include?(section_name)
    end

    if end_index
      @lines[start_index..(start_index + end_index)]
    else
      @lines[start_index..]
    end
  end

  # 技能カテゴリの判定
  def determine_skill_category(skill_name)
    # 括弧内の表記を除去
    clean_name = skill_name.gsub(/[（）()]/, '').strip

    case clean_name
    when /回避/
      :dodge
    when /拳銃|ライフル|ショットガン|サブマシンガン|マシンガン|ナイフ|投擲|棍棒|剣|斧|鞭|チェーンソー|弓/
      :attack
    when /こぶし|パンチ|キック|頭突き|マーシャルアーツ/
      :martialarts
    when /組み付き|組みつき/
      :grapple
    else
      :other
    end
  end

  # 武器名から技能名を抽出
  def extract_weapon_skill_name(weapon_name)
    # "ファイティング・ナイフ" -> "ナイフ"
    # "拳銃（.38口径）" -> "拳銃"

    clean_name = weapon_name.gsub(/[（）()]/, '').strip

    case clean_name
    when /ナイフ/
      'ナイフ'
    when /拳銃/
      '拳銃'
    when /ライフル/
      'ライフル'
    when /ショットガン/
      'ショットガン'
    when /サブマシンガン/
      'サブマシンガン'
    when /こぶし|パンチ/
      'こぶし'
    when /キック/
      'キック'
    else
      clean_name
    end
  end

  # ダメージボーナスが適用できるか
  def can_apply_damage_bonus?(weapon_name)
    # 近接武器のみDB適用可能
    weapon_name.match?(/ナイフ|こぶし|パンチ|キック|頭突き|棍棒|剣|斧|鞭|チェーンソー|マーシャルアーツ/)
  end

  # ダメージ式の正規化
  def normalize_damage_formula(damage_str)
    return nil if damage_str.nil? || damage_str.strip.empty?

    # "1d4+2+1d4" -> "1d4+2+1d4"
    # "1D10" -> "1d10"
    # 空白を除去して小文字化
    normalized = damage_str.strip.downcase.gsub(/\s+/, '')

    # 有効なダメージ式かチェック
    return unless normalized.match?(/\d+d\d+/) || normalized == '0' || normalized == '特殊'

    normalized
  end
end
