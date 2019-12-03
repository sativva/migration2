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

    def import_customers
      set_FTP_settings

      ftp = Net::FTP.new(@hostname, @username, @password)
      ftp.chdir(@folder)
      files = ftp.nlst('*.csv')
      files.each do |file|
        next unless file.include?('customers')
        localfile = File.basename(file)
        ftp.getbinaryfile(file, localfile, @blocksize)

        csv = CSV.open(localfile, headers: false,liberal_parsing: true)

        csv.first(100).each_with_index do |line, i|

          next if i == 0
          lili = line.join(',').to_s.gsub(/\"/, "").split(';')
          p ziqy_customer_id = lili[3]
          p a_name = lili[7]
          p company = lili[8].present? ? lili[8].gsub(/\,/,'') : nil
          p last_name = lili[9].present? ? lili[9].gsub(/\,/,'') : nil
          p first_name = lili[10].present? ? lili[10].gsub(/,/,'') : nil
          p address1 = lili[11].present? ? lili[11].gsub(/,/,'') : nil
          p address2 = lili[12].present? ? lili[12].gsub(/,/,'') : nil
          p zip = lili[13]
          p city = lili[14]
          p phone = lili[16]
          p lili[20]
          p created_at = DateTime.parse(lili[20])
          p updated_at = DateTime.parse(lili[21])
          p active = lili[22]
          p email = lili[32]
          if lili[37] == "0000-00-00" || lili[37].nil? || lili[37].empty?
            birthday  = nil
          else
            birthday = Date.parse(lili[37])
          end
          p accepts_marketing = lili[38].to_i == 1 ? true : false
          if accepts_marketing
            optin = lili[41].to_i == 1 ? "confirmed_opt_in" : "single_opt_in"
          else
            optin = "unknown"
          end

          cust = ShopifyAPIRetry.retry { ShopifyAPI::Customer.find(:all, params: { email: email })}
          cust = cust.present? ? cust.first : ShopifyAPI::Customer.new

          customer = {
            email: email,
            accepts_marketing: accepts_marketing,
            created_at: created_at,
            updated_at: updated_at,
            first_name: first_name,
            last_name: last_name,
            note: "birthday: #{birthday}",
            phone: phone,
            tags: "Ziqy, #{ziqy_customer_id}",
            addresses: [
                {
                  first_name: first_name,
                  last_name: last_name,
                  company: company,
                  address1: address1,
                  address2: address2,
                  city: city,
                  country: "France",
                  zip: zip,
                  phone: phone,
                  name: a_name,
                  country_code: "FR",
                  default: true
                }
            ],
            marketing_opt_in_level: optin,
            send_email_invite: false,
            metafields: [
                 {
                   key: "birthday",
                   value: birthday,
                   value_type: "string",
                   namespace: "global"
                 }
               ]
          }


          cust.id.present? ? (customer[:id] = cust.id) : (p 'new')
          sleep(0.5)

          cus = ShopifyAPI::Customer.new(customer)
          cus.save

        end
      end
    end
    def create_recharge_csv
      set_FTP_settings


      file_name = "lpb_recharge_#{today.strftime('%Y%m%d_%H%M%S')}.csv"
      csv_data = CSV.generate(col_sep: ";") do |csv|
        csv << %w(subscription_id shopify_product_name  shopify_variant_name  shopify_product_id  shopify_variant_id  quantity  recurring_price charge_interval_unit_type charge_interval_frequency shipping_interval_unit_type shipping_interval_frequency is_prepaid  charge_on_day_of_month  last_charge_date  next_charge_date  customer_stripe_id  customer_created_at shipping_email  shipping_first_name shipping_last_name  shipping_phone  shipping_address_1  shipping_address_2  shipping_city shipping_province shipping_zip  shipping_country  shipping_company  billing_first_name  billing_last_name billing_address_1 billing_address_2 billing_city  billing_postalcode  billing_province_state  billing_country billing_phone)


        ftp = Net::FTP.new(@hostname, @username, @password)
        ftp.chdir(@folder)
        files = ftp.nlst('*.csv')
        files.each do |file|
          next unless file.include?('commandes')
          csv = CSV.open(localfile, headers: false,liberal_parsing: true)
          csv.first(100).each_with_index do |line, i|
            next if i == 0
            lili = line[0].to_s.gsub(/\"/, "").split(';')

            line_items_variants_id = lpb_products(lili)
            line_items = {}
            line_items_variants_id.each do |v|
              next if v == "30734956232800" || v == "30734958559328"
              # next if lili[56].to_i.zero?
              product = @products.select {|product| product.variants.select {|variant| variant.id == v }}.first
              variant = product.variants.select {|variant| variant.id == v }
              order_date = DateTime.parse(lili[12])
              change_pricing_date = DateTime.parse("2018-12-12 00:00:31")

              if order_date < change_pricing_date
                price = 13.9
                abo_price = 12.9
              else
                price = 12.9
                abo_price = 11.9
              end
              line_items[v] = {}
              line_items[v][:variant_id] = v
              line_items[v][:quantity] = 1
              line_items[v][:price] = lili[6].to_i.zero? ? price : abo_price
              line_items[v][:title] =  product.title
              line_items[v][:variant_title] = variant.title
              line_items[v][:product_id] = product.id

            end



            line_items_variants_id.uniq.each do |variant_id|

              line = line_items[variant_id]

              recharge_line = []
              recharge_line << ""
              recharge_line << line["title"]
              recharge_line << line["variant_title"]
              recharge_line << line["product_id"]
              recharge_line << line["variant_id"]
              recharge_line << line["quantity"] #quantity
              recharge_line << line["price"] #recurring_price
              recharge_line << "Month" #charge_interval_unit_type
              recharge_line << 2 #charge_interval_frequency
              recharge_line << "Month" #shipping_interval_unit_type
              recharge_line << 2 #shipping_interval_frequency
              recharge_line << "no" #is_prepaid

              recharge_line << "variant_sho.id" #charge_on_day_of_month
              recharge_line << "variant_sho.id" #last_charge_date
              recharge_line << "variant_sho.id" #next_charge_date

              recharge_line << lili[56] #customer_stripe_id

              recharge_line << "variant_sho.id" #customer_created_at

              recharge_line << lili[13] #shipping_email
              recharge_line << lili[40] #shipping_first_name
              recharge_line << lili[39] #shipping_last_name
              recharge_line << lili[45] #shipping_phone
              recharge_line << lili[41] #shipping_address_1
              recharge_line << lili[42] #shipping_address_2
              recharge_line << lili[44] #shipping_city
              recharge_line << "" #shipping_province
              recharge_line << lili[44] #shipping_zip
              recharge_line << "France" #shipping_country
              recharge_line << lili[38] #shipping_company
              recharge_line << lili[49] #billing_first_name
              recharge_line << lili[48] #billing_last_name
              recharge_line << lili[50] #billing_address_1
              recharge_line << lili[51] #billing_address_2
              recharge_line << lili[53] #billing_city
              recharge_line << lili[52] #billing_postalcode
              recharge_line << "" #billing_province_state
              recharge_line << "France" #billing_country
              recharge_line << lili[54] #billing_phone
              csv << recharge_line
            end



          end
        end
      end
    end

    def import_orders
      set_FTP_settings
      location = ShopifyAPI::Location.all.map {|loc| loc.id }

      ftp = Net::FTP.new(@hostname, @username, @password)
      ftp.chdir(@folder)
      files = ftp.nlst('*.csv')
      files.each do |file|
        next unless file.include?('commandes')
        localfile = File.basename(file)
        ftp.getbinaryfile(file, localfile, @blocksize)

        csv = CSV.open(localfile, headers: false,liberal_parsing: true)
        csv.first(100).each_with_index do |line, i|
          next if i == 0

          lili = line[0].to_s.gsub(/\"/, "").split(';')
          tags = "#{lili[2]}, "
          tags += lili[6].to_i.zero? ?   "Eshop, " : "Box, "
          tags += lili[8].to_i.zero? ?  "" : "Carte Cadeau, "
          case lili[11]
            when "Expédié"
              fulfillment_status = "fulfilled"
            when "Livré"
              fulfillment_status = "fulfilled"
            when "En cours de préparation"
              fulfillment_status = nil
            when "Paiement accepté"
              fulfillment_status = nil
          end


          p lili[19].downcase.include?('paris')
          p location.first
          p location.last

          p location_id = lili[19].downcase.include?('paris') ? location.first : location.last

          tags += lili[22].to_i.zero? ? "" : "1bidon, "
          tags += lili[23].to_i.zero? ? "" : "2bidon, "
          tags += lili[24].to_i.zero? ? "" : "3bidon, "
          tags += lili[6].to_i.zero? ? "" : "echeance_nb:#{lili[37]} ,"

          line_items_variants_id = lpb_products(lili)


          p line_items_variants_id

          # line_items_variants_id = ["30202257735729",
          #                            "30308653727793",
          #                            "30308653793329",
          #                            "16360600207409",
          #                            "16360599814193",
          #                            "30961126244401",
          #                            "31343240249393",
          #                            "16360600633393",
          #                            "30961126408241",
          #                            "30347843469361",
          #                            "30147581771825",
          #                            "30347828068401",
          #                            "31235207692337",
          #                            "31235205398577",
          #                            "16360599846961",
          #                            "30346870063153",
          #                            "16360600404017"]

          # if lili[30]
          #   lili[30].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[25]
          #   lili[25].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[26]
          #   lili[26].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[31]
          #   lili[31].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[27]
          #   lili[27].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[32]
          #   lili[32].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[28]
          #   lili[28].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[33]
          #   lili[33].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[29]
          #   lili[29].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[34]
          #   lili[34].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[35]
          #   lili[35].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          # if lili[36]
          #   lili[36].to_i.times do
          #     line_items_variants_id << "30202257735729"
          #   end
          # end
          line_items = []

          order_date = DateTime.parse(lili[12])
          change_pricing_date = DateTime.parse("2018-12-12 00:00:31")
          tax_rate = 0.2
          if order_date < change_pricing_date
            price = 13.9
            abo_price = 12.9
          else
            price = 12.9
            abo_price = 11.9
          end
          line_items_variants_id.size

          line_items_variants_id.each do |v|
            b = Hash.new(0)
            b[:variant_id] = v
            b[:quantity] = 1
            b[:price] = lili[6].to_i.zero? ? price : abo_price
            b[:title] =  @products.select {|product| product.variants.select {|variant| variant.id == v }}.first.title
            line_items << b
          end


          tax_title = "TVA"
          ttc_price = lili[9].to_f
          ht_price = ttc_price / (tax_rate + 1)
          tax_price = ttc_price - ht_price
          o_name = lili[6].to_i.zero? ? "ZIQY#{lili[1]}" : "ZIQY#{lili[1]}--#{lili[37]}"
          order = {
            email: lili[13],
            tags: tags,
            name: o_name,
            total_price: ttc_price,
            financial_status: "paid",
            created_at: DateTime.parse(lili[12]),
            discount_codes: lili[21].empty? ? nil : [lili[21]],
            line_items: line_items,
            location_id: location_id,
            send_receipt: false,
            taxes_included: true,
            tax_lines: [
              price: tax_price,
              rate: tax_rate,
              title: "TVA"
            ],
            total_tax: tax_price,
            total_shipping_price_set: {
              shop_money: {
                amount: lili[20].empty? ? 0 : lili[20].to_f
              },
              presentment_money: {
                amount: lili[20].empty? ? 0 : lili[20].to_f
              }
            },
            transactions: [
              {
                status: "success",
                amount: ttc_price
              }
            ],
            shipping_lines: [{
              price: lili[20].empty? ? 0 : lili[20].to_f,
              source: lili[19],
              title: lili[19],
              tax_lines: [],
              carrier_identifier: lili[19]
            }],
            billing_address: {
              company: lili[46],
              last_name: lili[47],
              first_name: lili[48],
              address1: lili[49],
              address2: lili[50],
              zip: lili[51],
              city: lili[52],
              phone: lili[53],
              country: "France"

            },
            shipping_address: {
              company: lili[38],
              last_name: lili[39],
              first_name: lili[40],
              address1: lili[41],
              address2: lili[42],
              zip: lili[43],
              city: lili[44],
              phone: lili[45],
              country: "France"
            }
          }


          if order = ShopifyAPIRetry.retry { ShopifyAPI::Order.create(order) }
            p "_____________SAVED_____________________"
            sleep(1)
            fulfillment = {
              location_id: location_id,
              tracking_number: "",
              tracking_urls: [],
              notify_customer: false,
              service: lili[19],
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
    end

    def lpb_products(lili)
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
      line_items_variants_id
    end

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
      @products = ShopifyAPI::Product.find(:all, params: { limit: 10 })
      @customers = ShopifyAPI::Customer.find(:all, params: { limit: 10 })
      @orders = ShopifyAPI::Order.find(:all, params: { limit: 10 })
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
            fulfillment_status: "unfulfilled",
            customer: { id: @customers_ids.sample }}
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

