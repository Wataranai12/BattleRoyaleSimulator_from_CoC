class CreateBattles < ActiveRecord::Migration[7.1]
  def change
    create_table :battles do |t|
      t.integer :current_round
      t.boolean :is_finished

      t.timestamps
    end
  end
end
