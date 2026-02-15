class CreateAttackMethods < ActiveRecord::Migration[7.1]
  def change
    create_table :attack_methods do |t|
      t.references :character, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.string :show_name
      t.string :weapon_name
      t.string :base_damage
      t.boolean :can_apply_db
      t.boolean :can_apply_ma

      t.timestamps
    end
  end
end
