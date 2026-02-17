# frozen_string_literal: true

class CreateBattles < ActiveRecord::Migration[7.1]
  def change
    create_table :battles do |t|
      t.references :user, foreign_key: true
      t.integer :current_round, default: 0
      t.boolean :is_finished, default: false
      t.integer :battle_mode, default: 0, null: false # individual /team
      t.references :winner, foreign_key: { to_table: :characters }
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
