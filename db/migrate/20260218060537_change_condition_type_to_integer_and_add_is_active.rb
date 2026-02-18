class ChangeConditionTypeToIntegerAndAddIsActive < ActiveRecord::Migration[7.1]
  def up
    # 既存の Condition データを削除（型変換のため）
    execute "DELETE FROM conditions"
    
    # condition_type を string から integer に変更
    remove_column :conditions, :condition_type
    add_column :conditions, :condition_type, :integer, default: 0, null: false
    
    # is_active カラムがすでに存在する場合はスキップ
    unless column_exists?(:conditions, :is_active)
      add_column :conditions, :is_active, :boolean, default: true, null: false
    end
  end

  def down
    remove_column :conditions, :is_active if column_exists?(:conditions, :is_active)
    remove_column :conditions, :condition_type
    add_column :conditions, :condition_type, :string
  end
end
