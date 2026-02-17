# frozen_string_literal: true

class CreateCharacteristics < ActiveRecord::Migration[7.1]
  def change
    create_table :characteristics do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :value, null: false

      t.timestamps
    end
  end
end
