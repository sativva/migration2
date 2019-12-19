class Customer < ApplicationRecord
  belongs_to :shop
  validate :email, :uniqueness => true, :scope => :shop_id
end
