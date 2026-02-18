# frozen_string_literal: true

class BattlesController < ApplicationController
  skip_before_action :require_login, only: %i[new create show select_character], raise: false

  def new
    @battle = Battle.new
    # セッション初期化（文字列キーで統一）
    session[:battle_slots] ||= Array.new(4) { { 'character_id' => nil, 'team' => nil } }
    session[:battle_mode]  ||= 'individual'

    # show画面の「このキャラで戦闘準備へ」ボタンから来た場合
    if params[:character_id].present? && params[:slot].present?
      slot_index = params[:slot].to_i
      session[:battle_slots][slot_index] = {
        'character_id' => params[:character_id].to_i,
        'team'         => params[:team] || session[:battle_slots][slot_index]&.dig('team')
      }
      session.delete(:pending_slot)  # ✅ 確認済みなのでクリア
    end

    # モード切替
    session[:battle_mode] = params[:battle_mode] if params[:battle_mode].present?

    # 表示用データ（文字列キー/シンボルキー両対応）
    @slots = Array.new(4) do |i|
      slot = session[:battle_slots][i] || { 'character_id' => nil, 'team' => nil }
      {
        character: Character.find_by(id: slot['character_id'] || slot[:character_id]),
        team:      slot['team'] || slot[:team]
      }
    end

    @battle_mode = session[:battle_mode]
  end

  def remove_slot
    session[:battle_slots] ||= Array.new(4) { { 'character_id' => nil, 'team' => nil } }
    slot_index = params[:slot].to_i
    session[:battle_slots][slot_index] = { 'character_id' => nil, 'team' => nil }
    redirect_to new_battle_path, notice: 'スロットから削除しました'
  end

  def update_team
    session[:battle_slots] ||= Array.new(4) { { 'character_id' => nil, 'team' => nil } }
    slot_index = params[:slot].to_i
    slot = session[:battle_slots][slot_index] || {}
    session[:battle_slots][slot_index] = {
      'character_id' => slot['character_id'] || slot[:character_id],
      'team'         => params[:team]
    }
    redirect_to new_battle_path
  end

  def select_character
    @slot = params[:slot]
    @sample_characters = Character.where(is_sample: true)
    @my_characters = logged_in? ? current_user.characters : []
  end

  def create
    # 戦闘開始時にDBへ保存（後で実装）
  end

  def show; end
end
