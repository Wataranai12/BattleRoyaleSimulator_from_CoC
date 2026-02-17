# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.2.2'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.1.6'

# データベースとサーバーの基本
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'

# Hotwire / フロントエンド構成（Import Maps + Tailwind）
# これにより Node.js や Yarn への依存を排除します
gem 'importmap-rails'
gem 'stimulus-rails'
gem 'tailwindcss-rails'
gem 'turbo-rails'

# 認証・ユーティリティ
gem 'bootsnap', require: false
gem 'jbuilder'
gem 'sorcery'
gem 'sprockets-rails'
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
end

group :development do
  gem 'rubocop'
  gem 'web-console'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
end
