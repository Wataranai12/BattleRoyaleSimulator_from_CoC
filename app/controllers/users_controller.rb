# frozen_string_literal: true

class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      auto_login(@user) # 登録と同時にログインさせる
      redirect_to root_path, notice: 'ユーザー登録が完了しました'
    else
      flash.now[:alert] = '登録に失敗しました'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
