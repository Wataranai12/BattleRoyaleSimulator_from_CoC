# frozen_string_literal: true

class CreateAttackMethods < ActiveRecord::Migration[7.1]
  def change
    create_table :attack_methods do |t|
      t.references :character, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.string :show_name, null: false
      t.string :weapon_name, null: false
      t.string :base_damage, null: false
      t.boolean :can_apply_db, default: false
      t.boolean :can_apply_ma, default: false
      t.integer :condition_type
      t.integer :duration
      t.integer :effect_value

      t.timestamps
    end
  end
end
