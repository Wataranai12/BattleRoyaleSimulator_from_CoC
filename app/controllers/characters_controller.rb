# frozen_string_literal: true

# V3
class CharactersController < ApplicationController
  before_action :require_login
  before_action :set_character, only: %i[show update]

  def new
    @character = Character.new
    @sample_characters = Character.where(is_sample: true)
  end

  def show
    @character = Character
                 .includes(:characteristics, :skills, :attack_methods)
                 .find(params[:id])
  end

  def create
    if params[:sample_id].present?
      # --- パターン3: サンプルからのコピー ---
      sample = Character.find(params[:sample_id])

      @character = current_user.characters.build(
        name: sample.name,
        original_txt: sample.original_txt,
        damage_bonus: sample.damage_bonus,
        max_hp: sample.max_hp
      )

      sample.characteristics.each do |c|
        @character.characteristics.build(name: c.name, value: c.value)
      end

      # スキル名→スキルオブジェクトのマップを作成
      skill_map = {}
      sample.skills.each do |s|
        new_skill = @character.skills.build(name: s.name, category: s.category, success: s.success)
        skill_map[s.id] = new_skill
      end

      # 攻撃手段もコピー（スキルとの関連を維持）
      sample.attack_methods.each do |am|
        new_skill = skill_map[am.skill_id]
        next unless new_skill

        @character.attack_methods.build(
          skill: new_skill,
          show_name: am.show_name,
          weapon_name: am.weapon_name,
          base_damage: am.base_damage,
          can_apply_db: am.can_apply_db,
          can_apply_ma: am.can_apply_ma
        )
      end

      notice_msg = "サンプル「#{sample.name}」をあなたのリストに登録しました。"

    else
      # --- パターン1 & 2: テキスト解析 ---
      txt = params[:character][:original_txt].presence
      txt = params[:character][:file].read.force_encoding('UTF-8') if params[:character][:file].present?

      parser = CharacterParser.new(txt)
      parsed_data = parser.parse

      # ✅ parsed_data を手動でマッピング（build に直接渡さない）
      @character = current_user.characters.build(
        name: parsed_data[:name],
        damage_bonus: parsed_data[:damage_bonus],
        original_txt: txt,
        max_hp: parsed_data[:characteristics][:hp]
      )

      # 能力値を登録（hp/mp/san/ide/luck/know はcharacteristicsに含めない）
      skip_as_characteristic = %i[hp mp san idea luck know]
      parsed_data[:characteristics].each do |name, value|
        next if value.nil? || value.zero?
        next if skip_as_characteristic.include?(name)

        @character.characteristics.build(
          name: name.to_s.downcase,
          value: value
        )
      end

      # 技能を登録
      parsed_data[:skills].each do |skill_data|
        next if skill_data[:success].nil? || skill_data[:success] <= 0

        @character.skills.build(
          name: skill_data[:name],
          category: skill_data[:category] || :other,
          success: skill_data[:success]
        )
      end

      # 攻撃手段を登録（対応スキルがあるものだけ）
      parsed_data[:attack_methods].each do |method_data|
        skill = @character.skills.find { |s| s.name == method_data[:skill_name] }
        next unless skill

        @character.attack_methods.build(
          skill: skill,
          show_name: method_data[:show_name],
          weapon_name: method_data[:weapon_name],
          base_damage: method_data[:base_damage] || '1d3',
          can_apply_db: method_data[:can_apply_db] || false,
          can_apply_ma: method_data[:can_apply_ma] || false
        )
      end

      notice_msg = "「#{@character.name}」を登録しました。"
    end

    if @character.save
      # ✅ slot指定の有無にかかわらず必ず show 画面で確認
      # slot が指定されていた場合はセッションに保持 → show 画面のボタンで登録
      session[:pending_slot] = params[:slot].to_s if params[:slot].present?
      redirect_to character_path(@character), notice: notice_msg
    else
      Rails.logger.debug "=== Save failed: #{@character.errors.full_messages} ==="
      @sample_characters = Character.where(is_sample: true)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @character.update(character_params)
      if session[:pending_slot].present?
        slot = session.delete(:pending_slot).to_i
        session[:battle_slots] ||= Array.new(4) { { 'character_id' => nil, 'team' => nil } }
        session[:battle_slots][slot] = { 'character_id' => @character.id, 'team' => nil }
        redirect_to new_battle_path,
                    notice: "#{@character.name} をスロット#{slot + 1}に登録しました"
      else
        redirect_to character_path(@character), notice: '変更を保存しました'
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_character
    @character = Character.find(params[:id])
  end

  def character_params
    params.require(:character).permit(
      :name,
      :max_hp,
      :damage_bonus,
      characteristics_attributes: %i[id name value],
      skills_attributes: %i[id name success category],
      attack_methods_attributes: %i[id show_name weapon_name base_damage can_apply_db can_apply_ma]
    )
  end
end
