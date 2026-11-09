Rails.application.routes.draw do
  root "home#show"
  resources :orders, only: %i[index show new create]
end
