shop = Shop.last
shop.connect_to_store
customer = {
            email: "throndio2@gmail.com",
            accepts_marketing: true,
            first_name: 'Thomas',
            last_name: 'Rondio',
            note: 'hoho',
            phone: '0649840679',
            tags: "Ziqy, Customer, CIP",
            addresses: [
                {
                  first_name: "Thomas",
                  last_name: "last_name",
                  company: "company",
                  address1: "address1",
                  address2: "address2",
                  city: "city",
                  country: "France",
                  zip: "57903",
                  phone: "0649840679",
                  name: "a_name",
                  country_code: "FR",
                  default: true
                }
            ],
            marketing_opt_in_level: true,
            send_email_invite: false,
            metafields: [
                 {
                   key: "birthday",
                   value: "19/04/1983",
                   value_type: "string",
                   namespace: "global"
                 }
               ]
          }


cus = ShopifyAPI::Customer.new(customer)
cus.valid?
cus.save
cus.errors


ShopifyAPI::Customer.find(cus.id).metafields


