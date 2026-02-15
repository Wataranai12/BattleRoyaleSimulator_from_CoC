class BattlesController < ApplicationController
  # ログイン制限をスキップする設定
  skip_before_action :require_login, only: [:new, :create, :show], raise: false

  def new
    @battle = Battle.new
    if logged_in?
      @my_characters = current_user.characters
    else
      @my_characters = []
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