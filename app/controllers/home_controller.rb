  # frozen_string_literal: true

  class HomeController < ShopifyApp::AuthenticatedController
    layout "application"
    before_action :set_session

    require "shopify_api_retry"
    require 'faker'
    require 'nokogiri'
    require 'net/ftp'
    require 'csv'
    require 'date'

    def import_orders
      set_FTP_settings
      p @hostname
      p @username
      p @password
      p ftp = Net::FTP.new(@hostname, @username, @password)
      ftp.chdir(@folder)
      p files = ftp.nlst('*.csv')
      files.each do |file|
        next unless file.include?('commandes')
        localfile = File.basename(file)
        ftp.getbinaryfile(file, localfile, @blocksize)
        # csv = CSV.open(localfile, headers: true, liberal_parsing: true)
        # csv = CSV.read(localfile)
        csv = CSV.open(localfile, headers: false,liberal_parsing: true)
        csv.first(2).each_with_index do |line, i|
           next if i == 0
          p "________________________"
          p "________________________"
          p "________________________"
          p "________________________"

          # line[0].gsub(/\"\"/, '')
          lili = line[0].to_s.gsub(/\"/, "").split(';')
          p lili
          tags = "#{lili[0]}, "
          tags += lili[6].to_i ?  "Box, " : "Eshop, "
          tags += lili[7].to_i ?  "Carte Cadeau, " : ""
          p lili[11]
          case lili[11]
            when "Expédié"
              fulfillment_status = "fulfilled"
            when "Livré"
              fulfillment_status = "fulfilled"
            when "En cours de préparation"
              fulfillment_status = "pending"
            when "Paiement accepté"
              fulfillment_status = "pending"
            end
          location = ShopifyAPI::Location.all.map {|loc| loc.id }
          location_id = lili[19].include?('Paris') ? location.first : location.last

          tags += lili[22] ? "1bidon, " : ""
          tags += lili[23] ? "2bidon, " : ""
          tags += lili[24] ? "3bidon, " : ""
          tags += lili[37] ? "echeance_nb:#{lili[37]} ," : ""


          line_items_variants_id = []
          if lili[30]
            lili[30].to_i.times do
              line_items_variants_id << "30734961115232"
            end
          end
          if lili[25]
            lili[25].to_i.times do
              line_items_variants_id << "30734961115232"
            end
          end
          if lili[26]
            lili[26].to_i.times do
              line_items_variants_id << "30734960459872"
            end
          end
          if lili[31]
            lili[31].to_i.times do
              line_items_variants_id << "30734960459872"
            end
          end
          if lili[27]
            lili[27].to_i.times do
              line_items_variants_id << "30734956494944"
            end
          end
          if lili[32]
            lili[32].to_i.times do
              line_items_variants_id << "30734956494944"
            end
          end
          if lili[28]
            lili[28].to_i.times do
              line_items_variants_id << "30734959378528"
            end
          end
          if lili[33]
            lili[33].to_i.times do
              line_items_variants_id << "30734959378528"
            end
          end
          if lili[29]
            lili[29].to_i.times do
              line_items_variants_id << "30734961049696"
            end
          end
          if lili[34]
            lili[34].to_i.times do
              line_items_variants_id << "30734961049696"
            end
          end
          if lili[35]
            lili[35].to_i.times do
              line_items_variants_id << "30734958559328"
            end
          end
          if lili[36]
            lili[36].to_i.times do
              line_items_variants_id << "30734956232800"
            end
          end

          p line_items_variants_id

          line_items_variants_id = ["30202257735729",
                                     "30308653727793",
                                     "30308653793329",
                                     "16360600207409",
                                     "16360599814193",
                                     "30961126244401",
                                     "31343240249393",
                                     "16360600633393",
                                     "30961126408241",
                                     "30347843469361",
                                     "30147581771825",
                                     "30347828068401",
                                     "31235207692337",
                                     "31235205398577",
                                     "16360599846961",
                                     "30346870063153",
                                     "16360600404017"]
          line_items = []
          line_items_variants_id.each do |v|
            b = Hash.new(0)
            b[:variant_id] = v
            b[:quantity] = 1
            line_items << b
          end

          p line_items

          p order = {
            email: lili[13],
            tags: tags,
            name: lili[2],
            total_price: lili[9].to_i * 100,
            fulfillment_status: fulfillment_status,
            created_at: DateTime.parse(lili[12]),
            discount_codes: lili[21].empty? ? nil : [lili[21]],
            line_items: line_items,
            send_receipt: false
          }


          p order = ShopifyAPIRetry.retry { ShopifyAPI::Order.create(order) }
          p "_____________SAVED_____________________"
          sleep(1)
          fulfillment = {
            location_id: location_id,
            tracking_number: "",
            tracking_urls: [],
            notify_customer: false,
            order_id: order.id,
            prefix_options: { order_id: order.id },
          }
          sleep(1)

          if order = ShopifyAPIRetry.retry { ShopifyAPI::Fulfillment.create(fulfillment) }
            p 'fulfillment saved'
          end

        end

      end
    end




    def index
      @products = ShopifyAPI::Product.find(:all, params: { limit: 10 })
      @customers = ShopifyAPI::Customer.find(:all, params: { limit: 10 })
      @orders = ShopifyAPI::Order.find(:all, params: { limit: 10 })
      @webhooks = ShopifyAPI::Webhook.find(:all)
    end

    def destroy_orders
      ShopifyAPI::Order.find(:all, params: {limit: 250, status: 'any'}).each do |order|
        order.destroy
      end
    end



    def sho_create(order)
      @queue.shift
      ShopifyAPI::Order.create(order)
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
            fulfillment_status: "unfulfilled",
            customer: { id: @customers_ids.sample }}
        ShopifyAPIRetry.retry { ShopifyAPI::Order.create(order) }


        puts "1 order done"
        sleep(1)
      end
    end

      def set_FTP_settings
        @blocksize = 512
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

