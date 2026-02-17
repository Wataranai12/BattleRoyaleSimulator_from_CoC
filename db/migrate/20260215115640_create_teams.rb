# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :teams do |t|
      t.references :battle, null: false, foreign_key: true
      t.string :where_team # nil, 'A', 'B', 'C'
      t.string :color # UI表示用
      t.boolean :is_active, default: true

      t.timestamps
    end
  end
end
