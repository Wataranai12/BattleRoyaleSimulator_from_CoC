Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  resources :characters
  resources :battles, only: [:new, :create, :show]
  resources :users, only: [:new, :create]
  get 'login', to: 'user_sessions#new', as: :login
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy', as: :logout

  root 'static_pages#top'
end
