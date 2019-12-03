    Rails.application.routes.draw do
      root :to => 'home#index'
      mount ShopifyApp::Engine, at: '/'
      # root to: 'pages#home'
      get 'destroy_all_order', to: 'home#destroy_orders'
      get 'destroy_all_customers', to: 'home#destroy_customers'
      get 'create_sample_orders', to: 'home#create_sample_orders'

      get 'import_orders', to: 'lpb#import_orders'
      get 'import_customers', to: 'lpb#import_customers'
      get 'create_recharge_csv', to: 'lpb#create_recharge_csv'


      namespace :api, defaults: { format: :json } do
        namespace :v1 do
          get 'products', to: 'products#index'
        end
      end
      # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
    end



