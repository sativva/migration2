    class Shop < ActiveRecord::Base
      include ShopifyApp::SessionStorage

      def connect_to_store
        p session = ShopifyAPI::Session.new({domain: self.shopify_domain, token: self.shopify_token, api_version: api_version})
        p session.valid?
        p ShopifyAPI::Base.activate_session(session)

      end

      def api_version
        ShopifyApp.configuration.api_version
      end


    end



