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
# 状態異常用のカラムを直接追加
      t.integer :condition_type
      t.integer :duration
      t.integer :effect_value
      # 状態異常の種類を定義
      enum condition_type: {
        grappling: 0,
        grappled: 1,
        stunned: 2,
        poisoned: 3,
        shocked: 4
      }
      t.timestamps
    end
  end
end
