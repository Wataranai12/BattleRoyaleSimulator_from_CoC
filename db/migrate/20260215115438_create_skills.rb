class CreateSkills < ActiveRecord::Migration[7.1]
  def change
    create_table :skills do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name
      t.string :category
      t.integer :success

      t.timestamps
    end
  end
end
