class CreateSkills < ActiveRecord::Migration[7.1]
  def change
    create_table :skills do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name
      t.integer :category #0_other/1_attack/2_dodge/3_masialarts/4_grapple
      t.integer :success

      t.timestamps
    end
  end
end
