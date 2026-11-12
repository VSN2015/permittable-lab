Rails.application.routes.draw do
  root "home#show"
  resources :orders, only: %i[index show new create edit update]
  patch "orders/:id/status", to: "orders#change_status", as: :order_status
  get "/inspector/last", to: "inspector#show", as: :inspector_last if Inspector.enabled?
end
