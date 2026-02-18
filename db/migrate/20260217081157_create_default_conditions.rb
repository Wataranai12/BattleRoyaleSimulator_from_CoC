# frozen_string_literal: true

class CreateDefaultConditions < ActiveRecord::Migration[7.1]
  def change
    create_table :default_conditions do |t|
      t.references :attack_method, null: false, foreign_key: true
      t.integer :condition_type
      t.integer :duration
      t.integer :effect_value

      t.timestamps
    end
  end
end
