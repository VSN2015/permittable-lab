Rails.application.routes.draw do
  root "home#show"
  resources :orders, only: %i[index show new create]
  get "/inspector/last", to: "inspector#show", as: :inspector_last if Inspector.enabled?
end
