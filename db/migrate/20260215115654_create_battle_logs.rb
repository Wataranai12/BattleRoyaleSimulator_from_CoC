class CreateBattleLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :battle_logs do |t|
      t.references :battle, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.integer :target_id
      t.integer :round
      t.text :message
      t.string :action_type

      t.timestamps
    end
  end
end
