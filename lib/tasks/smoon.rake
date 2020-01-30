namespace :smoon do

  desc "Import Customer"
  task customer: :environment do
    puts 'smoon'
    import_customers
  end

  desc "TODO"
  task order: :environment do
  end
end

require "shopify_api_retry"
require 'faker'
require 'nokogiri'
require 'net/ftp'
require 'csv'
require 'date'

    def import_customers
      p 'import_customers'
      set_FTP_settings
      private_prod_api_destination

      ftp = Net::FTP.new(@hostname, @username, @password)
      ftp.chdir(@folder)
      files = ftp.nlst('*.csv')
      files.each do |file|
        next unless file.include?('customers')
        localfile = File.basename(file)
        ftp.getbinaryfile(file, localfile, @blocksize)
        csv = CSV.open(localfile, headers: false,liberal_parsing: true)
        csv.first(22).each_with_index do |line, i|
          sleep(0.5)
          p 'csveach'
          next if i == 0
          lili = line.join(';').to_s.gsub(/\"/, "").split(';')


          first_name = lili[1].present? ? lili[1].gsub(/,/,'') : ""
          last_name = lili[2].present? ? lili[2].gsub(/\,/,'') : ""
          email = lili[3]
          a_name = lili[9]


          address1 = lili[10].present? ? lili[10].gsub(/,/,'') : ""
          address2 = lili[11].present? ? lili[11].gsub(/,/,'') : ""
          zip = lili[14]
          city = lili[12]
          province = lili[13]
          phone = lili[16].present? ? lili[16].gsub('-', '').gsub(/\./, '').gsub(/\//, '')  : ""
          country =  pays(lili[15])
          country_code =  code_pays(lili[15])
          created_at = lili[8].present? ? DateTime.parse(lili[8]) : nil
          tags =  lili[0] == 'true' ? "has_account" : ""
          p cust = ShopifyAPIRetry.retry { ShopifyAPI::Customer.find(:all, params: { email: email })}
          next if cust.present?
          customer = {
            email: email,
            created_at: created_at,
            first_name: first_name,
            last_name: last_name,
            phone: phone,
            tags: tags,
            addresses: [
                {
                  last_name: a_name,
                  address1: address1,
                  address2: address2,
                  city: city,
                  country: country,
                  zip: zip,
                  phone: phone,
                  country_code: country_code,
                  default: true
                }
            ],
            send_email_invite: false
          }
          p cus = ShopifyAPI::Customer.new(customer)
          if ShopifyAPIRetry.retry { cus.save }
            p cus.email
            p "done"
          else
            p cus.email
            p cus.errors.messages
            p "errors"
          end
        end
      end
    end

    def code_pays(code)
      if code == "FRA"
        "FR"
      elsif code == "AUT"
        "AT"
      elsif code == "BEL"
        "BE"
      elsif code == "CAN"
        "CA"
      elsif code == "CHE"
        "CH"
      elsif code == "DEU"
        "DE"
      elsif code == "ESP"
        "ES"
      elsif code == "FIN"
        "FI"
      elsif code == "USA"
        "US"
      elsif code == "REU"
        "RE"
      elsif code == "PYF"
        "PF"
      elsif code == "NLD"
        "NL"
      elsif code == "NCL"
        "NC"
      elsif code == "MYT"
        "YT"
      elsif code == "MTQ"
        "MQ"
      elsif code == "MAR"
        "MA"
      elsif code == "LUX"
        "LU"
      elsif code == "ITA"
        "IT"
      elsif code == "IRL"
        "IE"
      elsif code == "HKG"
        "HK"
      elsif code == "GLP"
        "GP"
      elsif code == "GBR"
        "GB"
      end
    end

    def pays(code)
      if code == "FRA"
        "France"
      elsif code == "AUT"
        "Autriche"
      elsif code == "BEL"
        "Belgique"
      elsif code == "CAN"
        "Canada"
      elsif code == "CHE"
        "Suisse"
      elsif code == "DEU"
        "Allemagne"
      elsif code == "ESP"
        "Espagne"
      elsif code == "FIN"
        "Finlande"
      elsif code == "USA"
        "Etats-Unis"
      elsif code == "REU"
        "La Réunion"
      elsif code == "PYF"
        "Polynésie Francaise"
      elsif code == "NLD"
        "Pays-bas"
      elsif code == "NCL"
        "Nouvelle-Calédonie"
      elsif code == "MYT"
        "Mayotte"
      elsif code == "MTQ"
        "Martinique"
      elsif code == "MAR"
        "Maroc"
      elsif code == "LUX"
        "Luxembourg"
      elsif code == "ITA"
        "Italie"
      elsif code == "IRL"
        "Irelande"
       elsif code == "HKG"
        "Hong-Kong"
      elsif code == "GLP"
        "Guadeloupe"
      elsif code == "GBR"
        "Royaume-Uni"
      end
    end


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

    def private_prod_api_destination
      shop_url ='https://0250beef1e5eb99b14dc71f48ec038bc:bfb9ba6923b3202eda355a207959ba59@smoonlingerie.myshopify.com/'
      ShopifyAPI::Base.site = shop_url
      ShopifyAPI::Base.api_version = '2020-01'
    end

    def set_FTP_settings
      @blocksize = 1104738
      @username  = 'thomasrokr'
      @hostname  = 'ftp.cluster020.hosting.ovh.net'
      @password  = 'Street75'
      @folder = 'migration-shopify'
    end

