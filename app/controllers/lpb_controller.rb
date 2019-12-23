  # frozen_string_literal: true

  class LpbController < ShopifyApp::AuthenticatedController
    layout "application"
    before_action :set_session
    before_action :get_products, only: %w(import_orders create_recharge_csv)

    require "shopify_api_retry"
    require 'faker'
    require 'nokogiri'
    require 'net/ftp'
    require 'csv'
    require 'date'

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
          tags = "REFZIQY|#{lili[2]}, IDZIQY|#{lili[0]} "
          tags += lili[4].to_i.zero? ?   ", Eshop" : ", Subscription "
          tags += lili[6].to_i.zero? ?  "" : ", Carte Cadeau "
          case lili[9]
            when "Expédié"
              fulfillment_status = "fulfilled"
            when "Livré"
              fulfillment_status = "fulfilled"
            when "En cours de préparation"
              fulfillment_status = nil
            when "Paiement accepté"
              fulfillment_status = nil
          end


          p lili[16].downcase.include?('paris')
          p location.first
          p location.last

          p location_id = lili[16].downcase.include?('paris') ? location.first : location.last

          tags += lili[19].to_i.zero? ? "" : "1bidon, "
          tags += lili[20].to_i.zero? ? "" : "2bidon, "
          tags += lili[21].to_i.zero? ? "" : "3bidon, "
          tags += lili[4].to_i.zero? ? "" : "echeance_nb:#{lili[37]} ,"

          line_items_variants_id = lpb_products(lili)



          p line_items_variants_id
          line_items = []

          order_date = DateTime.parse(lili[12])
          date_first_export = DateTime.parse("2019-12-19 15:00:31")
          next if order_date > date_first_export


          change_pricing_date = DateTime.parse("2018-12-12 00:00:31")
          tax_rate = 0.2
          if order_date < change_pricing_date
            price = 13.9
            abo_price = 12.9
          else
            price = 12.9
            abo_price = 11.9
          end

          p line_items_variants_id.size

          line_items_variants_id.each do |v|
            if (v == "30734956232800" || v == "30734958559328" || v == "4422322946144")
              b = Hash.new(0)
              b[:variant_id] = v
              b[:quantity] = 1
              b[:price] = lili[6].to_i.zero? ? price : abo_price
              b[:title] =  @products.select {|product| product.variants.select {|variant| variant.id == v }}.first.title
            else
              b = Hash.new(0)
              b[:variant_id] = v
              b[:quantity] = 1
              b[:price] = lili[6].to_i.zero? ? price : abo_price
              b[:title] =  @products.select {|product| product.variants.select {|variant| variant.id == v }}.first.title
            end

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
          line_items_variants_id << "31511698800736"
        end
      end
      if lili[25]
        lili[25].to_i.times do
          line_items_variants_id << "31511698800736"
        end
      end
      if lili[26]
        lili[26].to_i.times do
          line_items_variants_id << "31511636541536"
        end
      end
      if lili[31]
        lili[31].to_i.times do
          line_items_variants_id << "31511636541536"
        end
      end
      if lili[27]
        lili[27].to_i.times do
          line_items_variants_id << "31512643371104"
        end
      end
      if lili[32]
        lili[32].to_i.times do
          line_items_variants_id << "31512643371104"
        end
      end
      if lili[28]
        lili[28].to_i.times do
          line_items_variants_id << "31512664277088"
        end
      end
      if lili[33]
        lili[33].to_i.times do
          line_items_variants_id << "31512664277088"
        end
      end
      if lili[29]
        lili[29].to_i.times do
          line_items_variants_id << "31512649564256"
        end
      end
      if lili[34]
        lili[34].to_i.times do
          line_items_variants_id << "31512649564256"
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
      if lili[63]
        lili[63].to_i.times do
          line_items_variants_id << "4422322946144"
        end
      end


      line_items_variants_id
    end

    def import_customers
      set_FTP_settings
      p 'import_customers'
      ftp = Net::FTP.new(@hostname, @username, @password)
      p @folder
      ftp.chdir(@folder)
      files = ftp.nlst('*.csv')
      p files
      files.each do |file|
        next unless file.include?('customers')
        localfile = File.basename(file)
        ftp.getbinaryfile(file, localfile, @blocksize)
        csv = CSV.open(localfile, headers: false,liberal_parsing: true)
        csv.each_with_index do |line, i|
          next if i == 0
          lili = line.join(',').to_s.gsub(/\"/, "").split(';')

          next if lili[0].blank?

          ziqy_customer_id = lili[0]

          company = lili[7].present? ? lili[7].gsub(/\,/,'') : nil
          first_name = lili[10].present? ? lili[10].gsub(/,/,'') : nil
          last_name = lili[11].present? ? lili[11].gsub(/\,/,'') : nil
          email = lili[12]

          a_name = lili[39] #wrong



          address1 = lili[40].present? ? lili[40].gsub(/,/,'') : nil
          address2 = lili[41].present? ? lili[41].gsub(/,/,'') : nil
          zip = lili[42]
          city = lili[43]
          phone = lili[45]

          created_at = DateTime.parse(lili[31])
          updated_at = DateTime.parse(lili[32])
          # active = lili[22]

          mondial_id = lili[49]
          mondial_company = lili[50]
          mondial_addr1 = lili[52]
          mondial_addr2 = lili[53]
          mondial_zip = lili[54]
          mondial_city = lili[55]
          mondial_country_code = lili[56]

          if lili[17] == "0000-00-00" || lili[17].nil? || lili[17].empty?
            birthday = nil
          else
            birthday = Date.parse(lili[17]).strftime("%d/%m/%Y")
          end

          p accepts_marketing = lili[18].to_i == 1 ? true : false
          if accepts_marketing
            optin = lili[21].to_i == 1 ? "confirmed_opt_in" : "single_opt_in"
          else
            optin = "unknown"
          end

          metafields = []

          if mondial_id.present?
            metafields << {
              key: "mondial_id",
              value: "#{mondial_country_code}#{mondial_id}",
              value_type: "string",
              namespace: "mondial_relay"
            }
            metafields << {
              key: "mondial_company",
              value: mondial_company,
              value_type: "string",
              namespace: "mondial_relay"
            }
            metafields << {
              key: "mondial_address1",
              value: mondial_addr1,
              value_type: "string",
              namespace: "mondial_relay"
            }
            metafields << {
              key: "mondial_address2",
              value: mondial_addr2,
              value_type: "string",
              namespace: "mondial_relay"
            }
            metafields << {
              key: "mondial_zip",
              value: mondial_zip,
              value_type: "string",
              namespace: "mondial_relay"
            }
            metafields << {
              key: "mondial_city",
              value: mondial_city,
              value_type: "string",
              namespace: "mondial_relay"
            }
            metafields << {
              key: "mondial_country",
              value: mondial_country_code,
              value_type: "string",
              namespace: "mondial_relay"
            }
          end
          if birthday.present?
            metafields << {
              key: "birthday",
              value: birthday,
              value_type: "string",
              namespace: "global"
            }
          end

          tags = "Ziqy, ZIQY-ID:#{ziqy_customer_id}"





          cust = ShopifyAPIRetry.retry { ShopifyAPI::Customer.find(:all, params: { email: email })}
          cust = cust.present? ? cust.first : ShopifyAPI::Customer.new

          customer = {
            email: email,
            accepts_marketing: accepts_marketing,
            created_at: created_at,
            updated_at: updated_at,
            first_name: first_name,
            last_name: last_name,
            phone: phone,
            tags: tags,
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
            metafields: metafields
          }


          cust.id.present? ? (customer[:id] = cust.id) : (p 'new')
          sleep(0.5)

          p cus = ShopifyAPI::Customer.new(customer)
          if cus.save
            Customer.create({
              name: cus.last_name,
              accepts_marketing: accepts_marketing.to_s,
              email: cus.email,
              first_name: cus.first_name,
              account_activation_url: cus.account_activation_url,
              shop_id: @shop.id
            })
          end


        end
      end
    end


    def create_recharge_csv
      set_FTP_settings
      today = Time.now


      file_name = "lpb_recharge_#{today.strftime('%Y%m%d_%H%M%S')}.csv"

        ftp = Net::FTP.new(@hostname, @username, @password)
        ftp.chdir(@folder)
        files = ftp.nlst('*.csv')
        files.each do |file|
          next unless file.include?('commandes')

          localfile = File.basename(file)
          csv_commandes = CSV.open(localfile, headers: false,liberal_parsing: true)

          csv_data = CSV.generate(col_sep: ";") do |csv_re|
            csv_re << %w(subscription_id shopify_product_name  shopify_variant_name  shopify_product_id  shopify_variant_id  quantity  recurring_price charge_interval_unit_type charge_interval_frequency shipping_interval_unit_type shipping_interval_frequency is_prepaid  charge_on_day_of_month  last_charge_date  next_charge_date  customer_stripe_id  customer_created_at shipping_email  shipping_first_name shipping_last_name  shipping_phone  shipping_address_1  shipping_address_2  shipping_city shipping_province shipping_zip  shipping_country  shipping_company  billing_first_name  billing_last_name billing_address_1 billing_address_2 billing_city  billing_postalcode  billing_province_state  billing_country billing_phone)

            p 'la'

          p mails_to_skip = []
          csv_commandes.reverse_each.each_with_index do |line, i|
            # p mails_to_skip
            lili = line.join(',').to_s.gsub(/\"/, "").gsub(/\"/, ",").split(';')

            next if i == 0
            next if lili[56].nil?
            next if lili[58] != 'ACTIVE'
            next if mails_to_skip.include?(lili[13])
            p "__________new____________"

            mails_to_skip << lili[13]
            line_items_variants_id = lpb_products(lili)
            p "line_items_variants_id: #{line_items_variants_id}"
            line_items = {}
            line_items_variants_id.each do |v|
              next if v == "30734956232800" || v == "30734958559328" || v == "4422322946144"

              variant = @products.map {|product| product.variants.select {|variant| variant.id.to_s == v }}.flatten.first
              product =  @products.select{|product| product.variants.map{|variant| variant.id }.include?(v.to_i) }.first

              order_date = DateTime.parse(lili[12])
              change_pricing_date = DateTime.parse("2018-12-12 00:00:31")

              if order_date < change_pricing_date
                price = 13.9
                abo_price = 12.9
              else
                price = 12.9
                abo_price = 11.9
              end
              p line_items[v] = {}
              p line_items[v][:variant_id] = v
              p line_items[v][:quantity] = (line_items[v][:quantity] || 0) + 1
              p line_items[v][:price] = lili[6].to_i.zero? ? price : abo_price
              p line_items[v][:title] =  product.title
              p line_items[v][:variant_title] = variant.title
              p line_items[v][:product_id] = product.id

            end


            p 'ICI'
            line_items_variants_id.uniq.each do |variant_id|
              next if variant_id.nil?
              # DO WE?
              next if variant_id == "30734956232800" || variant_id == "30734958559328" || v == "4422322946144"

              p "almost -- #{lili[13]}"
              p "almost -- #{lili[2]}"
              p "almost -- #{}"


              line = line_items[variant_id]
              recharge_line = []
              recharge_line << ""
              p line[:title]
              recharge_line << line[:title]
              recharge_line << line[:variant_title]
              recharge_line << line[:product_id]
              recharge_line << line[:variant_id]
              recharge_line << line[:quantity] #quantiy
              recharge_line << line[:price] #recurring_prie
              recharge_line << "Month" #charge_interval_unit_type
              recharge_line << 2 #charge_interval_frequency
              recharge_line << "Month" #shipping_interval_unit_type
              recharge_line << 2 #shipping_interval_frequency
              recharge_line << "no" #is_prepaid

              recharge_line << DateTime.parse(lili[12]).strftime('%d') #charge_on_day_of_month
              recharge_line << DateTime.parse(lili[12]).strftime('%m/%d/%Y')  #last_charge_date
              recharge_line << (DateTime.parse(lili[12]) + 2.month).strftime('%m/%d/%Y') #next_charge_date

              recharge_line << lili[56] #customer_stripe_id

              recharge_line << Date.parse(lili[62]).strftime('%m/%d/%Y') #customer_created_at

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





              csv_re << recharge_line



            end

          end
        end
        p "almost"

        temp_file = Tempfile.new(file_name)
        temp_file.write(csv_data)
        temp_file.close
        ftp.putbinaryfile(temp_file, file_name)
        temp_file.unlink

      end
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


    def set_FTP_settings
      @blocksize = 1104738
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

