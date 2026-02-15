class CreateConditions < ActiveRecord::Migration[7.1]
  def change
    create_table :conditions do |t|
      t.references :battle_participant, null: false, foreign_key: true
      t.string :condition_type
      t.integer :duration
      t.integer :effect_value

      t.timestamps
    end
  end
end
