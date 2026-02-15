class CharactersController < ApplicationController
  before_action :require_login
  
  def create
    # ファイルまたはテキストエリアからの入力を取得
    txt = params[:character][:original_txt]
    if params[:character][:file].present?
      txt = params[:character][:file].read.force_encoding("UTF-8")
    end

    # パーサーで解析して、一括保存用のハッシュを作成
    parser = CharacterParser.new(txt)
    parsed_data = parser.parse

    # 解析結果を元にインスタンスを作成（user_idも紐付け）
    @character = current_user.characters.build(parsed_data)
    @character.original_txt = txt # 元データも保存しておく

    if @character.save
      # 保存成功時、詳細画面ではなく「戦闘準備画面」へリダイレクト
      redirect_to new_battle_path, notice: "「#{@character.name}」を登録しました。続けてエントリーしてください。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def character_params
    # file は DB に保存しないため許可リストから外してもよいが、params全体で扱う
    params.require(:character).permit(:original_txt, :name)
  end
end
