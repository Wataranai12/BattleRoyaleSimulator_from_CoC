# frozen_string_literal: true

# app/helpers/characters_helper.rb

module CharactersHelper
  # 技能カテゴリに応じたBootstrapバッジの色を返す
  def category_badge_class(category)
    case category.to_s
    when 'dodge'       then 'bg-info text-dark'
    when 'attack'      then 'bg-danger'
    when 'martialarts' then 'bg-warning text-dark'
    when 'grapple'     then 'bg-secondary'
    else                    'bg-light text-dark border'
    end
  end
end
