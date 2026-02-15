class CreateCharacteristics < ActiveRecord::Migration[7.1]
  def change
    create_table :characteristics do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name
      t.integer :value

      t.timestamps
    end
  end
end
