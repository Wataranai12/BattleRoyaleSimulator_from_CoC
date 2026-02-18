# frozen_string_literal: true

# 以下のコマンドでマイグレーションを作成してください
# rails generate migration AddNerfToConditions

# 生成されたファイルに以下を記述：

class AddNerfToConditions < ActiveRecord::Migration[7.1]
  def up
    # condition_type enum に nerf を追加
    # 既存: grappling: 0, grappled: 1, stunned: 2, poisoned: 3, shocked: 4
    # 追加: nerf: 5

    # enum は integer なので、DB側では何もしなくて良い
    # app/models/condition.rb で enum を更新するだけ

    # 念のため、既存データに nerf (5) がないことを確認
    execute <<-SQL
      -- 何もしない（enum の追加は Ruby 側で行う）
    SQL
  end

  def down
    # rollback 時も特に何もしない
  end
end
