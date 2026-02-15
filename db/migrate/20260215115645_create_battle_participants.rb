class CreateBattleParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :battle_participants do |t|
      t.references :character, null: false, foreign_key: true
      t.references :battle, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.integer :current_hp
      t.boolean :is_active
      t.boolean :is_join

      t.timestamps
    end
  end
end
