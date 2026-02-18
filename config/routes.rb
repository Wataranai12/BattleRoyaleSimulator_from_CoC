# frozen_string_literal: true

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check
  resources :characters
  resources :battles do
    collection do
      get    :select_character
      delete :remove_slot
      patch  :update_team
    end
    
    member do
      post :execute_turn
      post :end_battle
      get  :export_log
    end
  end
  resources :users, only: %i[new create]
  get 'login', to: 'user_sessions#new', as: :login
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy', as: :logout

  root 'static_pages#top'
end
