# frozen_string_literal: true

class CreateBattleParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :battle_participants do |t|
      t.references :character, null: false, foreign_key: true
      t.references :battle, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.integer :current_hp, null: false
      t.boolean :is_active, default: true # 行動可能か
      t.boolean :is_join, default: true # 参戦中か
      # 統計用
      t.integer :kills_count, default: 0
      t.integer :damage_dealt, default: 0
      t.integer :damage_taken, default: 0

      t.timestamps
    end
  end
end
