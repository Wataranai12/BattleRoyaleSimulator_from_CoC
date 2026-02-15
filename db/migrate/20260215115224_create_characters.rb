class CreateCharacters < ActiveRecord::Migration[7.1]
  def change
    create_table :characters do |t|
      t.references :user, foreign_key: true
      t.string :name
      t.string :damage_bonus

      t.timestamps
    end
  end
end
