task testi: :environment do
  puts 'launching console'
  testi
  puts 'done.'
end

task import_orders: :environment do
  puts 'launching console'
  import_orders
  puts 'done.'
end

task bulk: :environment do
  puts 'launching console'
  send_bulk_invite
  puts 'done.'
end

task mvp: :environment do
  puts 'launching console'
  mvp
  puts 'done.'
end



task mvp: :environment do
  puts 'launching console'
  smoon
  puts 'done.'
end

require "shopify_api_retry"
require 'faker'
require 'nokogiri'
require 'net/ftp'
require 'csv'
require 'date'

    def send_bulk_invite
      set_session
      two_fifty = ShopifyAPIRetry.retry { ShopifyAPI::Customer.find(:all, params: {limit: 250, state: 'disabled'})}
      all_customers = two_fifty

      while two_fifty.count == 250
        puts 'next page____'
        sleep(0.5)
        two_fifty = ShopifyAPIRetry.retry { two_fifty.fetch_next_page }
        all_customers << two_fifty
        p all_customers.flatten.count
      end

      all_customers.flatten.each do |customer|
        p customer.email
        if customer.created_at.to_date < "2020-01-28T07:52:14+01:00".to_date
          if customer.state == 'disabled' and customer.email != nil
            ShopifyAPIRetry.retry { customer.send_invite }
            p customer.email
          end
        end
      end
    end

    def import_orders
      set_session
      set_FTP_settings
      get_products
      location = ShopifyAPIRetry.retry { ShopifyAPI::Location.all.map {|loc| loc.id } }
      p 'locations'
      p location
      ftp = Net::FTP.new(@hostname, @username, @password)
      ftp.chdir(@folder)
      files = ftp.nlst('*.csv')
      files.each do |file|
        next unless file.include?('orders')
        localfile = File.basename(file)
        ftp.getbinaryfile(file, localfile, @blocksize)
        # CSV::Converters[:my_converters] = lambda{ |field3|
        #   begin
        #     field3.to_s.gsub(/\n/, '$$$$$$$$$$')
        #   rescue ArgumentError
        #     field3
        #   end
        # }

        csv = CSV.open(localfile, headers: false, liberal_parsing: true)
        csv = csv.first(5100)
        csv.each_with_index do |line, i|
          next if i == 0

          lili = line.join(',').to_s.gsub(/\"/, "").split(';')
          p lili.length

          p csv[i]
          next if lili.length == 20

          if lili.length == 65
            lili = (csv[i]+csv[i+1]).join(',').to_s.gsub(/\"/, "").split(';')
            p lili.length
          end
          if lili.length != 84
            p lili[2]
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"
            p "__________________________________________________"

          end




          order_date = DateTime.parse(lili[10])
          date_first_export = DateTime.parse("2019-12-19 15:00:31")
          next if order_date > date_first_export
          tags = "REFZIQY|#{lili[2]}, IDZIQY|#{lili[1]} "
          tags += lili[4].to_i.zero? ?   ", Eshop" : ", Subscription "
          tags += lili[6].to_i.zero? ?  "" : ", Carte Cadeau "
          tags += ", STATEZIQY|#{lili[9]}"
          case lili[9]
            when "Expédié"
              fulfillment_status = "fulfilled"
            when "Livré"
              fulfillment_status = "fulfilled"
            when "En cours de préparation"
              fulfillment_status = nil
            when "En cours de livraison"
              fulfillment_status = nil
            when "Paiement accepté"
              fulfillment_status = nil
            when "Remboursé"
              fulfillment_status = nil
            when "Paiement à distance accepté"
              fulfillment_status = nil
            when "Annulé"
              next
          end


          p lili[16].downcase.include?('paris')
          p location.first
          p location.last
          p location_id = lili[16].downcase.include?('paris') ? location.first : location.last

          tags += lili[19].to_i.zero? ? "" : ", 1bidon"
          tags += lili[20].to_i.zero? ? "" : ", 2bidon"
          tags += lili[21].to_i.zero? ? "" : ", 3bidon"
          tags += lili[4].to_i.zero? ? "" : ", echeance_nb:#{lili[43]}"
          tags += lili[18].empty? ? "" : ", ZIQY-DISCOUNT|#{lili[18]}"

          lpb_products_result = lpb_products(lili)

          p discount = lpb_products_result[:discount]
          line_items = []

          tax_rate = 0.2


          lpb_products_result[:line_items_variants_id].each do |v|
            b = Hash.new(0)
            b[:variant_id] = v[:id]
            b[:quantity] = v[:quantity]
            b[:price] = v[:price]
            if v[:id] == '4259267772512' || v[:id] == '4460046581856'
              b[:title] =  @products.select {|product| product.id == v[:id].to_i }.first.title
            else
              b[:title] =  @products.select {|product| product.variants.map {|variant| variant.id }.include?(v[:id].to_i)}.first.title
            end
            line_items << b
          end
          p lili[63].present?
          metafields = []
          if lili[63].present?

            metafields << {
              key: "mondial_id",
              value: "#{lili[70]}#{lili[63]}",
              value_type: "string",
              namespace: "mondial_relay"
            }
            if lili[64].present?
            metafields << {
              key: "mondial_company",
              value: lili[64],
              value_type: "string",
              namespace: "mondial_relay"
            }
            end
            if lili[69].present?

            metafields << {
              key: "mondial_address1",
              value: lili[66],
              value_type: "string",
              namespace: "mondial_relay"
            }
            end
            if lili[67].present?
            metafields << {
              key: "mondial_address2",
              value: lili[67],
              value_type: "string",
              namespace: "mondial_relay"
            }
            end
            if lili[68].present?
            metafields << {
              key: "mondial_zip",
              value: lili[68],
              value_type: "string",
              namespace: "mondial_relay"
            }
            end
            if lili[69].present?
            metafields << {
              key: "mondial_city",
              value: lili[69],
              value_type: "string",
              namespace: "mondial_relay"
            }
            end
            if lili[70].present?
            metafields << {
              key: "mondial_country",
              value: lili[70],
              value_type: "string",
              namespace: "mondial_relay"
            }
            end
          end

          p 'tvz'

          tax_title = "TVA"
          ttc_price = lili[7].to_f
          ht_price = ttc_price / (tax_rate + 1)
          tax_price = ttc_price - ht_price
          if lili[1].length == 1
            order_number = "0000#{lili[1]}"
          elsif lili[1].length == 2
            order_number = "000#{lili[1]}"
          elsif lili[1].length == 3
            order_number = "00#{lili[1]}"
          elsif lili[1].length == 4
            order_number = "0#{lili[1]}"
          elsif lili[1].length == 5
            order_number = "#{lili[1]}"
          end

          p o_name = lili[4].to_i.zero? ? "ZIQY#{order_number}" : "ZIQY#{order_number}--#{lili[43]}"
          p ooo =  ShopifyAPIRetry.retry { ShopifyAPI::Order.find(:all, params: {status: 'any', name: o_name, limit:'250' }).size }

          next if ooo > 0

          p "order_ready"

          order_ready = {
            email: lili[11],
            tags: tags,
            name: o_name,
            total_price: ttc_price,
            financial_status: "paid",
            created_at: DateTime.parse(lili[10]),
            total_discounts: discount.to_f,
            # discount_codes: lili[18].empty? ? nil : [lili[18]],
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
                amount: lili[17].empty? ? 0 : lili[17].to_f
              },
              presentment_money: {
                amount: lili[17].empty? ? 0 : lili[17].to_f
              }
            },
            transactions: [
              {
                status: "success",
                amount: ttc_price
              }
            ],
            shipping_lines: [{
              price: lili[17].empty? ? 0 : lili[17].to_f,
              source: lili[16],
              title: lili[16],
              tax_lines: [],
              carrier_identifier: lili[16]
            }],
            billing_address: {
              company: lili[53],
              last_name: lili[54],
              first_name: lili[55],
              address1: lili[56],
              address2: lili[57],
              zip: lili[58],
              city: lili[59],
              phone: lili[60],
              country: "France"

            },
            shipping_address: {
              company: lili[44],
              last_name: lili[45],
              first_name: lili[46],
              address1: lili[47],
              address2: lili[48],
              zip: lili[49],
              city: lili[50],
              phone: lili[51],
              country: "France"
            },
            metafields: metafields
          }



          ooo = ShopifyAPI::Order.new(order_ready)
          if !ooo.nil? && ShopifyAPIRetry.retry { ooo.save }
            o_id = ooo.id
            ooo = nil
            p "_____________SAVED_____________________"
            sleep(0.5)
            fulfillment = {
              location_id: location_id,
              tracking_number: "",
              tracking_urls: [],
              notify_customer: false,
              service: lili[16],
              order_id: o_id,
              prefix_options: { order_id: o_id }
            }
            sleep(0.5)

            if fulfill = ShopifyAPIRetry.retry { ShopifyAPI::Fulfillment.create(fulfillment) }
              p '_____________fulfillment saved'
            end
          else
            p "__________________errors #{ooo.errors.messages}"
          end


        end

      end
    end



    def lpb_products(lili)
      p "lpb_products"
      line_items_variants_id = []
      total_line_price = lili[17].to_f

      if lili[19] == "1"
        price_of_each = (lili[71].to_f * 1.2)
      elsif lili[20] == "1"
        price_of_each = (lili[72].to_f * 1.2) / 2
      elsif lili[21] == "1"
        price_of_each = (lili[73].to_f * 1.2) / 3
      end

      if lili[22].to_i > 0
        line_items_variants_id << {id: "31511698800736", price: price_of_each, quantity: lili[22]}
        total_line_price += price_of_each * lili[22].to_i
      end
      if lili[27].to_i > 0
          line_items_variants_id << {id: "31511698800736", price: (lili[79] * 1.2).to_f, quantity: lili[27]}
          total_line_price += (lili[79].to_f * 1.2) * lili[27].to_i
      end
      if lili[23].to_i > 0
          line_items_variants_id << {id: "31511636541536", price: price_of_each, quantity: lili[23]}
          total_line_price += price_of_each * lili[23].to_i
      end
      if lili[28].to_i > 0
          line_items_variants_id << {id: "31511636541536", price: (lili[80].to_f * 1.2), quantity: lili[28]}
          total_line_price += (lili[80].to_f * 1.2) * lili[28].to_i
      end
      if lili[24].to_i > 0
          line_items_variants_id << {id: "31512643371104", price: price_of_each, quantity: lili[24]}
          total_line_price += price_of_each * lili[24].to_i
      end
      if lili[29].to_i > 0
          line_items_variants_id << {id: "31512643371104", price: (lili[81].to_f * 1.2), quantity: lili[29]}
          total_line_price += (lili[81].to_f * 1.2) * lili[29].to_i
      end
      if lili[25].to_i > 0
          line_items_variants_id << {id: "31512664277088", price: price_of_each, quantity: lili[25]}
          total_line_price += price_of_each * lili[25].to_i
      end
      if lili[30].to_i > 0
          line_items_variants_id << {id: "31512664277088", price: (lili[82].to_f * 1.2), quantity: lili[30]}
          total_line_price += (lili[82].to_f * 1.2) * lili[30].to_i
      end
      if lili[26].to_i > 0
          line_items_variants_id <<  {id: "31512649564256", price: price_of_each, quantity: lili[26]}
          total_line_price += price_of_each  * lili[26].to_i
      end
      if lili[31].to_i > 0
          line_items_variants_id << {id: "31512649564256", price: (lili[83].to_f * 1.2), quantity: lili[31]}
          total_line_price += (lili[83].to_f * 1.2) * lili[31].to_i
      end
      if lili[32].to_i > 0
          line_items_variants_id << {id: "4460046581856", price: (lili[39].to_f * 1.2), quantity: lili[32]}
          total_line_price += (lili[39].to_f * 1.2) * lili[32].to_i
      end
      if lili[33].to_i > 0
          line_items_variants_id << {id: "4259267772512", price: (lili[40].to_f * 1.2), quantity: lili[33]}
          total_line_price += (lili[40].to_f * 1.2) * lili[33].to_i
      end
      if lili[42].to_i > 0
          line_items_variants_id << {id: "31622336217184", price: (lili[41].to_f * 1.2), quantity: lili[42]}
          total_line_price += (lili[41].to_f * 1.2) * lili[42].to_i
      end

      discount = 0
      if total_line_price.round(2) != lili[7].to_f.round(2)
        discount = total_line_price - lili[7].to_f
      end


      p result = {line_items_variants_id: line_items_variants_id, discount: discount}
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
      # @shop = Shop.where(shopify_domain: session[:shopify_domain]).first
      @shop = Shop.where(shopify_domain: "mes-voisins-producteurs2.myshopify.com").first
      @shop.connect_to_store
      rescue
        set_session_from_params
    end

    def set_session_from_params
      @shop = Shop.where(shopify_domain: params[:shopify_domain]).first
      @shop.connect_to_store

    end


    def testi
      Shop.all.each do |shop|
        shop.connect_to_store
        @products = ShopifyAPI::Product.find(:all, params: { limit: 100 })
        @customers = ShopifyAPI::Customer.find(:all, params: { limit: 100 })
        @orders = ShopifyAPI::Order.find(:all, params: { limit: 100 })
        @webhooks = ShopifyAPI::Webhook.find(:all)
        binding.pry
      end

    end

    def mvp
      @all_orders = []
      problems = []
      def private_prod_api_origin
        shop_url = "https://bf227c6b157c312b8466028957ca7171:f8279fc264660d34b94add101621e3d4@mes-voisins-producteurs.myshopify.com/"
        # shop_url = "https://bf227c6b157c312b8466028957ca7171:f8279fc264660d34b94add101621e3d4@mes-voisins-producteurs.myshopify.com/"
        ShopifyAPI::Base.site = shop_url
        ShopifyAPI::Base.api_version = '2020-01'
      end

      def private_test_api_destination
        shop_url = "https://b5e7b69dad09183d37d1ae8a7288c9fa:84edf1954f09b9a2a45b44fab4aa459d@thomas-test-theme.myshopify.com/"
        ShopifyAPI::Base.site = shop_url
        ShopifyAPI::Base.api_version = '2020-01'
      end

      def private_prod_api_destination
        shop_url ='https://ea85c614cdfc2d59fe7e8d2f32d6dd54:73300234a46ab53bd6e11a7ddb5d9a55@mes-voisins-producteurs2.myshopify.com/'
        ShopifyAPI::Base.site = shop_url
        ShopifyAPI::Base.api_version = '2020-01'
      end

      def all_orders
        private_prod_api_origin
        puts "all orders first"
        puts ShopifyAPI::Base.site

        two_fifty = ShopifyAPIRetry.retry { ShopifyAPI::Order.find(:all, params: { limit: 250, status: 'any' }) }
        migrate(two_fifty.select { |o| o.number.to_i < 3540 })

        while two_fifty.count == 250
          private_prod_api_origin
          puts "all orders while"
          puts ShopifyAPI::Base.site

          puts "next page____#{two_fifty.count}"
          sleep(0.5)
          two_fifty = ShopifyAPIRetry.retry { two_fifty.fetch_next_page }
          migrate(two_fifty.select { |o| o.number.to_i < 3119 })
        end
      end

      def method_name
        orders = []
        of.each do |n|
          orders << ShopifyAPIRetry.retry { ShopifyAPI::Order.find(:all, params: {status: 'any', name: n}) }.first
        end

      end

      def migrate_discount
        private_prod_api_origin
        discounts = []
        pr = ShopifyAPIRetry.retry { ShopifyAPI::PriceRule.find(:all, params: {limit: 250}) }
        newp = pr.select do |kk|
          if kk.attributes.has_key? ('ends_at') and kk.ends_at.present?
            p kk.ends_at
            kk.ends_at.to_date < Date.today
          end
        end
        migrate_discounts(newp)
        while pr.count == 250
          private_prod_api_origin
          puts "all discount while"
          puts ShopifyAPI::Base.site
          puts "next page____#{pr.count}"
          sleep(0.5)
          pr = ShopifyAPIRetry.retry { pr.fetch_next_page }
          migrate_discounts(pr)
        end
      end

      def migrate_discounts(pr)

        p 'hooo'
        pr.each do |ppr|
          poper = ppr.id
          piper = ppr

          piper.id = nil
          pppr = ShopifyAPI::PriceRule.new(piper.attributes)

          private_prod_api_destination
          p 'hii'
          if ShopifyAPIRetry.retry { pppr.save }
            piper.id = poper
            p 'HOHO'
            private_prod_api_origin
            piper.discount_codes.select {|pr| pr.created_at.to_date < "2020-01-29T19:45:02+01:00".to_date }.each do |dd|
              p pppr.id
              dd.id = nil
              dd.prefix_options = {price_rule_id: pppr.id}
              dd.price_rule_id = pppr.id
              private_prod_api_destination
              if ShopifyAPIRetry.retry { dd.save }
                p 'youpi'
                p dd.code
              end
            end
          end
        end

      end

      def migrate(orders)
              puts "migrate"
        private_prod_api_destination
        puts ShopifyAPI::Base.site
        orders.each_with_index do |order, i|
          p "processing #{order.name}"

          p i

          order.line_items.each do |line_item|
            sleep(0.01)
            line_item.id = nil
            line_item.product_id = nil
            line_item.variant_id = nil
            line_item.origin_location = nil
            line_item.admin_graphql_api_id = nil
          end
          # {
          #   line_items: order.line_items,
          #   email: order.email,
          #   created_at: order.created_at,
          #   note: order.note,
          #   gateway: order.gateway,
          #   total_price: order.total_price,
          #   subtotal_price: order.subtotal_price,
          #   total_weight: order.total_weight,
          #   financial_status: order.financial_status,
          #   total_line_items_price: order.total_line_items_price,
          #   name: "#{order.name}-v1",
          #   cancelled_at: order.cancelled_at,
          #   note_attributes: order.note_attributes,
          #   discount_codes: order.discount_codes,
          #   fulfillment_status: order.fulfillment_status,
          #   shipping_lines: order.shipping_lines,
          #   shipping_address: order.shipping_address
          # }
          # order.fulfillments = nil
          # order.source_name = nil
          # order.sent_receipt = false
          # order.id = nil
          # order.name = "#{order.name}-v1"
          # order.tax_lines = nil
          # order.customer = nil

          unless order.shipping_lines.empty?
            order.shipping_lines.each {|sl| sl.id = nil }
          end
          # ShopifyAPI::Order.create(order.attributes)
          # exists?
          exists = ShopifyAPIRetry.retry { ShopifyAPI::Order.find(:all, params: {status: 'any', name: order.name}) }
          if exists.length == 0
            o_new = ShopifyAPI::Order.new({
            line_items: order.line_items,
            email: order.email,
            created_at: order.created_at,
            note: order.note,
            gateway: order.gateway,
            total_price: order.total_price,
            subtotal_price: order.subtotal_price,
            total_weight: order.total_weight,
            financial_status: order.financial_status,
            total_line_items_price: order.total_line_items_price,
            name: "#{order.name}-v1",
            cancelled_at: order.cancelled_at,
            note_attributes: order.note_attributes,
            discount_codes: order.discount_codes,
            fulfillment_status: order.fulfillment_status,
            shipping_lines: order.shipping_lines


          })
            if order.attributes.has_key? ('shipping_address')
              o_new.shipping_address = order.shipping_address
            end
            sleep(0.5)
            begin
              if ShopifyAPIRetry.retry { o_new.save }
                p "did it #{o_new.name}"
              else
                p o_new.errors.messages
              end
            rescue
              p @problems << o_new.name
            end
          end

        end

      all_orders

of = ["#4403",
 "#4547",
 "#4394",
 "#4367",
 "#4315",
 "#4118",
 "#4080",
 "#3530",
 "#3490",
 "#3482",
 "#3055",
 "#3046",
 "#3039",
 "#2939",
 "#2839",
 "#2838",
 "#2837",
 "#2836",
 "#2588",
 "#2583",
 "#2577",
 "#2570",
 "#2547",
 "#2483",
 "#2481",
 "#2479",
 "#2475",
 "#2445",
 "#2444",
 "#2442",
 "#2429",
 "#2406",
 "#2405",
 "#2402",
 "#2375",
 "#2306",
 "#2300",
 "#2294",
 "#2289",
 "#2288",
 "#2286",
 "#2267",
 "#2262",
 "#2223",
 "#2219",
 "#2217",
 "#2213",
 "#2185",
 "#2184",
 "#2182",
 "#2181",
 "#2180",
 "#2178",
 "#2176",
 "#2175",
 "#2173",
 "#2111",
 "#2070",
 "#2058",
 "#2055",
 "#2050",
 "#2046",
 "#2041",
 "#2040",
 "#2009",
 "#1959",
 "#1855",
 "#1614",
 "#1593",
 "#1568",
 "#1500",
 "#1491",
 "#1-1009",
 "#1470",
 "#1443",
 "#1440",
 "#1409",
 "#1-1008",
 "#1-1007",
 "#1-1006",
 "#1251",
 "#1-1004",
 "#1-1003",
 "#1120",
 "#1079",
 "#1078",
 "#1-1002",
 "#1048",
 "#1042",
 "#1-1001",
 "#4790",
 "#4789",
 "#4788",
 "#4787",
 "#4786",
 "#4785",
 "#4784",
 "#4783",
 "#4782",
 "#4781",
 "#4780",
 "#4779",
 "#4778",
 "#4777",
 "#4776",
 "#4775",
 "#4774",
 "#4773",
 "#4772",
 "#4771",
 "#4770",
 "#4769",
 "#4768",
 "#4767",
 "#4766",
 "#4765",
 "#4764",
 "#4763",
 "#4762",
 "#4761",
 "#4760",
 "#4759",
 "#4758",
 "#4757",
 "#4756",
 "#4755",
 "#4754",
 "#4753",
 "#4752",
 "#4751",
 "#4750",
 "#4749",
 "#4748",
 "#4747",
 "#4746",
 "#4745",
 "#4744",
 "#4743",
 "#4742",
 "#4741"]
    end





















    def smoon_blog
      shop_url = "https://0250beef1e5eb99b14dc71f48ec038bc:bfb9ba6923b3202eda355a207959ba59@smoonlingerie.myshopify.com/"
      ShopifyAPI::Base.site = shop_url
      ShopifyAPI::Base.api_version = '2020-01'
      set_FTP_settings
      ftp = Net::FTP.new(@hostname)
      ftp.login(user = @username, passwd = @password, acct = nil)
      ftp.chdir("#{@folder}")
      files = ftp.nlst('*.xml')

      file = files.first
      localfile = File.basename(file)
      xml_string = ftp.getbinaryfile(file, localfile, @blocksize)
      doc = File.open(file) { |f| Nokogiri::XML(f) }
      @item = doc.xpath("/rss/channel/item")
      @item.each_with_index do |node, i|

        @type = node.xpath("./wp:post_type").text
        if @type == "post"
          if @item[i+1].xpath("./wp:post_type").text == "attachment"
            image =  @item[i+1].xpath("./link").text
          end

          status = node.xpath("./wp:status").text
          title = node.xpath("./title").text
          created_at = node.xpath("./pubDate").text
          author = node.xpath("./dc:creator").text
          content = node.xpath("./content:encoded").text
          excerpt = node.xpath("./excerpt:encoded").text

          excerpt.gsub('<![CDATA[', '')
          content.gsub('<![CDATA[', '')
          excerpt.gsub('<![CDATA[', '')
          content.gsub('<![CDATA[', '')
          article  = ShopifyAPI::Article.new({
            "title": title,
            "author": author,
            "tags": "",
            "body_html": content,
            "published_at": created_at,
            "summary_html": excerpt,
            "image": {
              "src": image,
              "alt": title
            }
          })

          ShopifyAPIRetry.retry { article.save }
            # node.xpath("./item/").text

        end
      end
    end


end
