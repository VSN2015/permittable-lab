class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :items

  validates :sku, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
end
