# frozen_string_literal: true

class CreateCharacters < ActiveRecord::Migration[7.1]
  def change
    create_table :characters do |t|
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.string :damage_bonus
      t.integer :max_hp
      t.text :original_txt
      t.boolean :is_sample, default: false

      t.timestamps
    end
  end
end
