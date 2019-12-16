 # frozen_string_literal: true

  class HomeController < ShopifyApp::AuthenticatedController
    layout "application"
    before_action :set_session
    before_action :get_products, only: %w(import_orders create_recharge_csv)

    require "shopify_api_retry"
    require 'faker'
    require 'nokogiri'
    require 'net/ftp'
    require 'csv'
    require 'date'


    def get_products
      puts '__________  get_products_from_shop'
      @products = ShopifyAPIRetry.retry {ShopifyAPI::Product.find(:all, params: { limit: 250 })}
      while @products.count == 250
        puts 'next page____'
        sleep(0.5)
        @products = ShopifyAPIRetry.retry { @products.fetch_next_page }
      end
      # rescue StandardError
      #   p 'get_products_from_shop FAILED'
    end

    def index
      @products = ShopifyAPI::Product.find(:all, params: { limit: 100 })
      @customers = ShopifyAPI::Customer.find(:all, params: { limit: 250 })
      @orders = ShopifyAPI::Order.find(:all, params: { limit: 250, status: 'any' })
      @webhooks = ShopifyAPI::Webhook.find(:all)
    end

    def destroy_orders
      ShopifyAPI::Order.find(:all, params: {limit: 250, status: 'any'}).each do |order|
        ShopifyAPIRetry.retry { order.destroy }
      end
    end

    def destroy_customers
      ShopifyAPI::Customer.find(:all, params: {limit: 250}).each do |customer|
        ShopifyAPIRetry.retry { customer.destroy }
      end
    end


    def create_sample_orders
      @customers_ids = []
      @cip = "cip- #{rand(10 ** 10)}"
      @tags = [@cip, @cip, @cip, "particulier", "particulier", "particulier"]
      c = ShopifyAPI::Customer.all
      c.each do |x|
        @customers_ids << x.id
      end

      @variant_ids = []
      products = ShopifyAPI::Product.all
      products.each do |product|
        product.variants.each do |variant|
          n = {'quantity' => rand(1..9), 'variant_id' => variant.id }
          @variant_ids << n
        end
      end



      6.times do
        puts "creates 1 order"
          order = {
            line_items: [@variant_ids.sample],
            tags: @tags.sample,
            shipping_address:   {
              "address1": Faker::Address.street_address,
              "address2": Faker::Address.street_address,
              "city": Faker::Address.city,
              "zip": Faker::Address.zip_code,
              "last_name": Faker::Name.unique.last_name,
              "first_name": Faker::Name.unique.first_name,
              "country": Faker::Address.country_code
            },
            financial_status: "paid",
            fulfillment_status: "unfulfilled"
            # customer: { id: @customers_ids.sample }
            }
        ShopifyAPIRetry.retry { ShopifyAPI::Order.create(order) }


        puts "1 order done"
        sleep(1)
      end
    end

    def set_FTP_settings
      @blocksize = 5120
      @username  = 'thomasrokr'
      @hostname  = 'ftp.cluster020.hosting.ovh.net'
      @password  = 'Street75'
      @folder = 'migration-shopify'
    end


    def set_session
      @shop = Shop.where(shopify_domain: session[:shopify_domain]).first
      @shop.connect_to_store
      rescue
        set_session_from_params
    end

    def set_session_from_params
      @shop = Shop.where(shopify_domain: params[:shopify_domain]).first
      @shop.connect_to_store

    end

  end

