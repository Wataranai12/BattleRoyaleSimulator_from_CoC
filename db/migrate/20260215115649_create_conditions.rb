# frozen_string_literal: true

class CreateConditions < ActiveRecord::Migration[7.1]
  def change
    create_table :conditions do |t|
      t.references :battle_participant, null: false, foreign_key: true
      # 誰がこの状態を付与したかを記録（自分自身の場合や環境の場合は nil も許容）
      t.integer :origin_participant_id, index: true
      t.integer :condition_type, null: true
      t.integer :duration, default: 0
      t.integer :effect_value
      t.boolean :is_active, default:0, null: false

      t.timestamps
    end
  end
end
