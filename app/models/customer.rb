class Customer < ApplicationRecord
  belongs_to :shop
  validates :email, :uniqueness => true, :scope => :shop_id
end
