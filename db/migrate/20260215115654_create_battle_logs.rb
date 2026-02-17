# frozen_string_literal: true

class CreateBattleLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :battle_logs do |t|
      t.references :battle, null: false, foreign_key: true
      t.references :character, foreign_key: true # 能動側
      t.references :target, foreign_key: { to_table: :characters } # 受動側
      t.integer :round, null: false
      t.text :message, null: false
      t.string :action_type, null: false
      t.text :ai_narration # Gemini実況文
      t.jsonb :details # 追加詳細情報（ダイス目など）

      t.timestamps
    end
  end
end
