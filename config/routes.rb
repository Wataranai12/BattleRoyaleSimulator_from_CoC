Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  # ユーザー登録用のルート
  resources :users, only: [:new, :create]

  # ログイン機能用のルート
  get 'login', to: 'user_sessions#new', as: :login
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy', as: :logout

  root 'static_pages#top'
end
