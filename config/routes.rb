    Rails.application.routes.draw do
      root :to => 'home#index'
      mount ShopifyApp::Engine, at: '/'
      # root to: 'pages#home'
      get 'destroy_all_order', to: 'home#destroy_orders'
      get 'create_sample_orders', to: 'home#create_sample_orders'
      get 'import_orders', to: 'home#import_orders'


      namespace :api, defaults: { format: :json } do
        namespace :v1 do
          get 'products', to: 'products#index'
        end
      end
      # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
    end



