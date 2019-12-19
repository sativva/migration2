class Customer < ApplicationRecord
  belongs_to :shop
  validates :email, uniqueness: { scope: :shop }
end
