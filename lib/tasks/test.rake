task testi: :environment do
  puts 'launching console'
  testi
  puts 'done.'
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
