# frozen_string_literal: true

class CharactersController < ApplicationController
  before_action :require_login

  def new
    @character = Character.new
    @sample_characters = Character.where(is_sample: true)
  end

  def create
    if params[:sample_id].present?
      # --- パターン3: サンプルからのコピー ---
      sample = Character.find(params[:sample_id])

      # キャラクター基本情報の複製
      @character = current_user.characters.build(
        name: sample.name,
        damage_bonus: sample.damage_bonus,
        original_txt: "Sample copied: #{sample.name}"
      )

      # 関連データのビルド（この時点ではメモリ上）
      # 能力値のコピー
      sample.characteristics.each do |c|
        @character.characteristics.build(name: c.name, value: c.value)
      end

      # 技能のコピー
      sample.skills.each do |s|
        @character.skills.build(name: s.name, category: s.category, success: s.success)
      end

      notice_msg = "サンプル「#{sample.name}」をあなたのリストに登録しました。"
    else
      # --- パターン1 & 2: テキスト解析 ---
      txt = params[:character][:original_txt]
      txt = params[:character][:file].read.force_encoding('UTF-8') if params[:character][:file].present?

      parser = CharacterParser.new(txt)
      parsed_data = parser.parse

      @character = current_user.characters.build(parsed_data)
      @character.original_txt = txt
      notice_msg = "「#{@character.name}」を登録しました。"
    end

    # ここでまとめて保存（トランザクション的に一気に保存されます）
    if @character.save
      redirect_to new_battle_path, notice: notice_msg
    else
      @sample_characters = Character.where(user_id: nil)
      render :new, status: :unprocessable_entity
    end
  end

  private

  # 深いコピー（関連データもすべて複製）を行うメソッド
  def copy_character_for_user(sample, user)
    new_char = sample.dup
    new_char.user_id = user.id
    new_char.name = sample.name.to_s # 必要なら "(コピー)" 等を付与

    # save前に子要素をビルドしておくことで、まとめて保存される
    sample.characteristics.each do |c|
      new_char.characteristics.build(c.attributes.except('id', 'character_id', 'created_at', 'updated_at'))
    end
    sample.skills.each do |s|
      new_char.skills.build(s.attributes.except('id', 'character_id', 'created_at', 'updated_at'))
    end

    # AttackMethods は skill_id との紐付けが複雑になるため、保存後に処理するのが安全ですが
    # ここでは一旦シンプルに基本情報のみコピーし、後で調整も可能です
    new_char
  end
end
