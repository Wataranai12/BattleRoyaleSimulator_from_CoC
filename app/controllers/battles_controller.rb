# frozen_string_literal: true

class BattlesController < ApplicationController
  # ログイン制限をスキップする設定
  skip_before_action :require_login, only: %i[new create show], raise: false

  def new
    @battle = Battle.new
    session[:battle_slots] ||= [nil, nil, nil, nil]

    if params[:character_id].present? && params[:slot].present?
      slot_index = params[:slot].to_i
      session[:battle_slots][slot_index] = params[:character_id].to_i
    end

    # セッションの復元でnilが消えても、常に4要素に揃える
    @slots = Array.new(4) { |i| Character.find_by(id: session[:battle_slots][i]) }

    @my_characters = logged_in? ? current_user.characters : []
    @sample_characters = Character.where(is_sample: true)
  end

  def remove_slot
    session[:battle_slots] ||= [nil, nil, nil, nil]
    slot_index = params[:slot].to_i
    session[:battle_slots][slot_index] = nil
    redirect_to new_battle_path, notice: "スロットから削除しました"
  end

  def select_character
    @slot = params[:slot]
    @sample_characters = Character.where(is_sample: true)
    @my_characters = logged_in? ? current_user.characters : []
  end
  
  def create
    # ここにバトルのログや結果を表示するロジックを後で書きます
  end

  def show
    # ここにバトルのログや結果を表示するロジックを後で書きます
  end
end
