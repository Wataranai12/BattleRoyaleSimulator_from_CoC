# frozen_string_literal: true

class CharacterParser
  class ParseError < StandardError; end

  FORMATS = {
    iakyara: 'いあきゃら',
    charaeno: 'Charaeno',
    character_storage: 'キャラクター保管所'
  }.freeze

  PARSER_MAP = {
    iakyara: CharacterParsers::IakyaraParser,
    charaeno: CharacterParsers::CharaenoParser,
    character_storage: CharacterParsers::CharacterStorageParser
  }.freeze

  def initialize(text_data)
    @text = text_data
    @lines = text_data.split("\n")
    @format = detect_format
  end

  def parse
    parser_class = PARSER_MAP[@format]
    raise ParseError, "未対応のフォーマットです。対応フォーマット: #{FORMATS.values.join(', ')}" unless parser_class

    parser_class.new(@text).parse
  rescue ParseError
    raise
  rescue StandardError => e
    Rails.logger.error("Character parsing failed: #{e.message}\n#{e.backtrace.join("\n")}")
    raise ParseError, "データの解析に失敗しました: #{e.message}"
  end

  # 以降は parse_and_create_character など既存メソッドをそのまま残す
  # ...

  private

  def detect_format
    check_lines = @lines.first(10).map(&:strip).join("\n")
    return :iakyara if check_lines.match?(/いあきゃらテキスト\s*6版/)
    return :character_storage if @lines.first&.match?(/^タイトル[：:]/)
    return :charaeno if check_lines.match?(/STR:\d+\s+DEX:\d+\s+INT:\d+/)
    return :iakyara if @text.match?(/【能力値】/) && @text.match?(/【技能値】/)
    return :character_storage if @text.match?(/■能力値■/) && @text.match?(/■技能■/)
    return :charaeno if @text.match?(/耐久力[：:]/) && @text.match?(/マジック[・･]ポイント[：:]/)
    nil
  end
end
