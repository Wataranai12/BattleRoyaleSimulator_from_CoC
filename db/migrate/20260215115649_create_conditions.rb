class CreateConditions < ActiveRecord::Migration[7.1]
  def change
    create_table :conditions do |t|
      t.references :battle_participant, null: false, foreign_key: true
      # 誰がこの状態を付与したかを記録（自分自身の場合や環境の場合は nil も許容）
      t.integer :origin_participant_id, index: true
      t.string :condition_type
      t.integer :duration
      t.integer :effect_value

      t.timestamps
    end
    # 外部キー制約を明示的に追加（同じテーブルへの参照）
    add_foreign_key :conditions, :battle_participants, column: :origin_participant_id
  end
end
