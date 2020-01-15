  # frozen_string_literal: true

  class LpbController < ShopifyApp::AuthenticatedController
    layout "application"
    before_action :set_session
    before_action :get_products, only: %w(import_orders create_recharge_csv create_recharge_csv_2)

    require "shopify_api_retry"
    require 'faker'
    require 'nokogiri'
    require 'net/ftp'
    require 'csv'
    require 'date'

    # Check IF order exists by name == OK
    # discount codes
    # ooos = ShopifyAPI::Order.find(:all, params:{status: "any"})
    # ooos.select {|o| o.name.include?('ZIQY')}.each {|o| o.destroy }

    #(sql 47, 49, 57, 59)
    def import_orders
      set_FTP_settings
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
        csv = csv.first(4100)
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
            b[:title] =  @products.select {|product| product.variants.map {|variant| variant.id }.include?(v[:id].to_i)}.first.title

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

    def lpb_products_recharge(lili)
      line_items_variants_id = []
      total_line_price = 0

      if lili[17] == "1"
        price_of_each = (lili[20].to_f)
      elsif lili[18] == "1"
        price_of_each = (lili[21].to_f) / 2
      elsif lili[19] == "1"
        price_of_each = (lili[22].to_f) / 3
      end

      #fleurs blanches
      if lili[23].to_i > 0
        line_items_variants_id << {id: "31511698800736", price: price_of_each, quantity: lili[23], p_id: "4259268067424", sub: true}
        total_line_price += price_of_each * lili[23].to_i
      end
      if lili[28].to_i > 0
          line_items_variants_id << {id: "31511698800736", price: (lili[35]).to_f, quantity: lili[28], p_id: "4259268067424"}
          total_line_price += (lili[35].to_f) * lili[28].to_i
      end
      #eucalyptus
      if lili[24].to_i > 0
          line_items_variants_id << {id: "31511636541536", price: price_of_each, quantity: lili[24], p_id: "4259267936352", sub: true}
          total_line_price += price_of_each * lili[24].to_i
      end
      if lili[29].to_i > 0
          line_items_variants_id << {id: "31511636541536", price: (lili[36].to_f), quantity: lili[29], p_id: "4259267936352"}
          total_line_price += (lili[36].to_f) * lili[29].to_i
      end

      if lili[25].to_i > 0
          line_items_variants_id << {id: "31512643371104", price: price_of_each, quantity: lili[25], p_id: "4259267838048", sub: true}
          total_line_price += price_of_each * lili[25].to_i
      end
      if lili[30].to_i > 0
          line_items_variants_id << {id: "31512643371104", price: (lili[37].to_f), quantity: lili[30], p_id: "4259267838048"}
          total_line_price += (lili[37].to_f) * lili[30].to_i
      end
      if lili[26].to_i > 0
          line_items_variants_id << {id: "31512664277088", price: price_of_each, quantity: lili[26], p_id: "4259267903584", sub: true}
          total_line_price += price_of_each * lili[26].to_i
      end
      if lili[31].to_i > 0
          line_items_variants_id << {id: "31512664277088", price: (lili[38].to_f), quantity: lili[31], p_id: "4259267903584"}
          total_line_price += (lili[38].to_f) * lili[31].to_i
      end
      if lili[27].to_i > 0
          line_items_variants_id <<  {id: "31512649564256", price: price_of_each, quantity: lili[27], p_id: "4259268001888", sub: true}
          total_line_price += price_of_each  * lili[27].to_i
      end
      if lili[32].to_i > 0
          line_items_variants_id << {id: "31512649564256", price: (lili[39].to_f), quantity: lili[32], p_id: "4259268001888"}
          total_line_price += (lili[39].to_f) * lili[32].to_i
      end

      if lili[33].to_i > 0
          line_items_variants_id << {id: "31660422135904", price: (lili[40].to_f), quantity: lili[33]}
          total_line_price += (lili[40].to_f) * lili[33].to_i
      end
      if lili[34].to_i > 0
          line_items_variants_id << {id: "30734956232800", price: (lili[41].to_f), quantity: lili[34]}
          total_line_price += (lili[41].to_f) * lili[34].to_i
      end
      if lili[43].to_i > 0
          line_items_variants_id << {id: "31622336217184", price: (lili[42].to_f), quantity: lili[43]}
          total_line_price += (lili[42].to_f) * lili[43].to_i
      end

      discount = 0
      if total_line_price.round(2) != lili[7].to_f.round(2)
        discount = total_line_price - lili[7].to_f
      end


      result = {line_items_variants_id: line_items_variants_id, discount: discount}
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
              line_items_variants_id << {id: "31660422135904", price: (lili[39].to_f * 1.2), quantity: lili[32]}
              total_line_price += (lili[39].to_f * 1.2) * lili[32].to_i
          end
          if lili[33].to_i > 0
              line_items_variants_id << {id: "30734956232800", price: (lili[40].to_f * 1.2), quantity: lili[33]}
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




    #(sql 40)
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
          p lili
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
          p cust.id.present?
          p '____'

          if cust.id.present?
            (customer[:id] = cust.id)
            next if cust.state == "enabled"
            qq = Customer.new
            qq.name = cust.last_name
            qq.accepts_marketing = accepts_marketing.to_s
            qq.email = cust.email
            qq.first_name = cust.first_name
            qq.account_activation_url = cust.account_activation_url
            qq.shop_id = @shop.id
            ShopifyAPIRetry.retry { qq.save }

          else
            (p 'new')
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
    end

    def create_recharge_csv_2
      rulseset_id = "225483"
      unique_ruleset_id = "227711"
      prod_comp = %w(31622336217184 30734956232800 31660422135904)
      lessive_one_time = %w(31511698800736 31511636541536 31512643371104 31512664277088 31512649564256)
      no_sub_prod = prod_comp + lessive_one_time

      set_FTP_settings
      today = Time.now

      file_name = "lpb_recharge_#{today.strftime('%Y%m%d_%H%M%S')}.csv"

      ftp = Net::FTP.new(@hostname, @username, @password)
      ftp.chdir(@folder)
      files = ftp.nlst('*.csv')
      csv_data = CSV.generate(col_sep: ";") do |csv_re|
        csv_re << %w(subscription_id shopify_product_name shopify_variant_name shopify_product_id  shopify_variant_id  quantity  recurring_price charge_interval_unit_type charge_interval_frequency shipping_interval_unit_type shipping_interval_frequency is_prepaid  charge_on_day_of_month  last_charge_date  next_charge_date  customer_stripe_id  customer_created_at shipping_email  shipping_first_name shipping_last_name  shipping_phone  shipping_address_1  shipping_address_2  shipping_city shipping_province shipping_zip  shipping_country  shipping_company  billing_first_name  billing_last_name billing_address_1 billing_address_2 billing_city  billing_postalcode  billing_province_state  billing_country billing_phone status discount_code original_shipping_title original_shipping_price)

        files.each do |file|
          # Requete 61 paid but not delivery february
          next unless file.include?('_61') || file.include?('_63') || file.include?('_64') || file.include?('_66') || file.include?('_67')
          p file
          localfile = File.basename(file)
          ftp.getbinaryfile(file, localfile, @blocksize)

          csv_commandes = CSV.open(localfile, headers: false,liberal_parsing: true)


          mails_to_skip = []
          csv_commandes.each_with_index do |line, i|
            # p mails_to_skip
            lili = line.join(',').to_s.gsub(/\"/, "").gsub(/\"/, ",").split(';')

            next if i == 0


            # p "__________new____________"



            line_items = {}

            line_items_variants_id = lpb_products_recharge(lili)
            # p "line_items_variants_id: #{line_items_variants_id}"

            line_items_variants_id[:line_items_variants_id].each do |v|

              # !!!
            next if !v[:sub]

            variant = @products.map {|product| product.variants.select {|variant| variant.id.to_s == v[:id] }}.flatten.first
            product =  @products.select{|product| product.variants.map{|variant| variant.id }.include?(v[:id].to_i) }.first


            line_items[v[:id]] = {}
            line_items[v[:id]][:variant_id] = variant.id
            line_items[v[:id]][:quantity] = v[:quantity].to_i
            line_items[v[:id]][:price] = v[:price]
            line_items[v[:id]][:title] = product.title
            line_items[v[:id]][:variant_title] = variant.title
            line_items[v[:id]][:product_id] = product.id
            line_items[v[:id]][:sub] = v[:sub]

            variant_id = v[:id]

            next if variant_id.nil?
            # DO WE?
            # produit complementaire

            line = line_items[variant_id]




            recharge_line = []
            if line[:sub]
              recharge_line << rulseset_id
            elsif localfile.include?("61")
              recharge_line << unique_ruleset_id
            end

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

            if localfile.include?("_61") || localfile.include?("_64") || localfile.include?("_63")
              recharge_line << 27 #charge_on_day_of_month
              recharge_line << ""  #last_charge_date
              recharge_line << "01/27/2020" #next_charge_date
            else
              recharge_line << 27 #charge_on_day_of_month
              recharge_line << ""  #last_charge_date
              recharge_line << "02/27/2020" #next_charge_date
            end

            # recharge_line << DateTime.parse(lili[12]).strftime('%d') #charge_on_day_of_month
            # recharge_line << DateTime.parse(lili[12]).strftime('%m/%d/%Y')  #last_charge_date
            # recharge_line << (DateTime.parse(lili[12]) + 2.month).strftime('%m/%d/%Y') #next_charge_date

            recharge_line << lili[6] #customer_stripe_id

            recharge_line << "" #customer_created_at

            recharge_line << lili[46] #shipping_email
            recharge_line << lili[47] #shipping_first_name
            recharge_line << lili[48] #shipping_last_name

            recharge_line << lili[65] #shipping_phone

            recharge_line << lili[52] #shipping_address_1
            recharge_line << lili[53] #shipping_address_2
            recharge_line << lili[55] #shipping_city
            recharge_line << "" #shipping_province
            recharge_line << lili[54] #shipping_zip


            recharge_line << lili[62] #shipping_country
            recharge_line << lili[64] #shipping_company


            recharge_line << lili[57] #billing_first_name
            recharge_line << lili[56] #billing_last_name
            recharge_line << lili[58] #billing_address_1
            recharge_line << lili[59] #billing_address_2
            recharge_line << lili[61] #billing_city
            recharge_line << lili[60] #billing_postalcode
            recharge_line << "" #billing_province_state
            recharge_line << "France" #billing_country


            recharge_line << lili[66] #billing_phone

            if localfile.include?("_64") || localfile.include?('_67')
              recharge_line << 'cancelled'
            else
              recharge_line << ''
            end


            if localfile.include?("_61")
              recharge_line << 'MIGRATION' #discount_code
              recharge_line << lili[44] #original_shipping_title
              recharge_line << 0 #original_shipping_price
            else
              recharge_line << '' #discount_code
              recharge_line << lili[44] #original_shipping_title
              recharge_line << lili[45] #original_shipping_price
            end

            csv_re << recharge_line
            end
          end
        end
      end
      temp_file = Tempfile.new(file_name)
      temp_file.write(csv_data)
      temp_file.close
      ftp.putbinaryfile(temp_file, file_name)
      temp_file.unlink
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
            csv_re << %w(subscription_id shopify_product_name shopify_variant_name shopify_product_id  shopify_variant_id  quantity  recurring_price charge_interval_unit_type charge_interval_frequency shipping_interval_unit_type shipping_interval_frequency is_prepaid  charge_on_day_of_month  last_charge_date  next_charge_date  customer_stripe_id  customer_created_at shipping_email  shipping_first_name shipping_last_name  shipping_phone  shipping_address_1  shipping_address_2  shipping_city shipping_province shipping_zip  shipping_country  shipping_company  billing_first_name  billing_last_name billing_address_1 billing_address_2 billing_city  billing_postalcode  billing_province_state  billing_country billing_phone)

            p 'la'

            mails_to_skip = []
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
                next if v == "30734956232800" || v == "31660422135904" || v == "31622336217184"

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
                next if variant_id == "30734956232800" || variant_id == "31660422135904" || v == "31622336217184"

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

