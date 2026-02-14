Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  # ユーザー登録用のルート
  resources :users, only: [:new, :create]

  # ログイン機能用のルート（後で使います）
  get 'login', to: 'user_sessions#new', as: :login
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy', as: :logout

  # トップページの設定（とりあえずユーザー登録画面に飛ばすか、専用のページを作る）
  # ここでは一旦、登録画面をルートに設定してみます
  root 'users#new'
  #root 'static_pages#top'
end
