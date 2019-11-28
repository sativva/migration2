    Rails.application.routes.draw do
      root :to => 'home#index'
      mount ShopifyApp::Engine, at: '/'
      # root to: 'pages#home'
      namespace :api, defaults: { format: :json } do
        namespace :v1 do
          get 'products', to: 'products#index'
        end
      end
      # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
    end



