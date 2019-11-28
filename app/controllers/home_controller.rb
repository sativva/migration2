  # frozen_string_literal: true
  class HomeController < ShopifyApp::AuthenticatedController
    layout "application"
    def index
      @products = ShopifyAPI::Product.find(:all, params: { limit: 10 })
      @webhooks = ShopifyAPI::Webhook.find(:all)
    end
  end

