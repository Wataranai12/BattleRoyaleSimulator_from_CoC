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
    # 戦闘開始：セッションからDBへ保存
    slots = session[:battle_slots] || []
    characters = slots.map { |s| Character.find_by(id: s['character_id']) }.compact
    
    if characters.size < 2
      redirect_to new_battle_path, alert: '参加者が2人以上必要です' and return
    end
    
    @battle = Battle.create!(
      battle_mode: session[:battle_mode] || 'individual',
      current_round: 0,
      is_finished: false
    )
    
    # チーム戦の場合はTeam作成
    if @battle.battle_mode == 'team'
      teams_data = slots.map { |s| s['team'] }.compact.uniq
      teams = {}
      teams_data.each do |team_name|
        teams[team_name] = @battle.teams.create!(
          where_team: team_name,
          color: team_color(team_name),
          is_active: true
        )
      end
    end
    
    # BattleParticipant作成
    slots.each_with_index do |slot, index|
      next unless slot['character_id']
      char = Character.find(slot['character_id'])
      
      # max_hp がない場合は HP 特性値から取得、それもなければ 10
      max_hp = char.max_hp || char.characteristics.find_by(name: 'hp')&.value || 10
      
      @battle.battle_participants.create!(
        character: char,
        team: @battle.battle_mode == 'team' ? teams[slot['team']] : nil,
        current_hp: max_hp,
        is_active: true
      )
    end
    
    # シミュレーター初期化
    simulator = BattleSimulator.new(@battle)
    simulator.start_battle
    
    redirect_to battle_path(@battle)
  end

  def show
    @battle = Battle.includes(battle_participants: { character: [:characteristics, :skills] }).find(params[:id])
    @participants = @battle.battle_participants.order('id ASC')
    @logs = @battle.battle_logs.order(created_at: :desc).limit(100)
  end
  
  def execute_turn
    @battle = Battle.find(params[:id])
    simulator = BattleSimulator.new(@battle)
    simulator.execute_round
    redirect_to battle_path(@battle)
  end
  
  def end_battle
    @battle = Battle.find(params[:id])
    @battle.update!(is_finished: true)
    redirect_to new_battle_path, notice: '戦闘を中断しました'
  end
  
  private
  
  def team_color(team_name)
    colors = { 'A' => '#dc3545', 'B' => '#0d6efd', 'C' => '#198754' }
    colors[team_name] || '#6c757d'
  end
end
