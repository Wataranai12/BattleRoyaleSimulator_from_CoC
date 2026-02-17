# frozen_string_literal: true

class BattlesController < ApplicationController
  # ログイン制限をスキップする設定
  skip_before_action :require_login, only: %i[new create show], raise: false

  def new
    @battle = Battle.new
    @my_characters = if logged_in?
                       current_user.characters
                     else
                       []
                     end
    @sample_characters = Character.where(user_id: nil)
  end

  def create
    # ここにバトルのログや結果を表示するロジックを後で書きます
  end

  def show
    # ここにバトルのログや結果を表示するロジックを後で書きます
  end
end
