class Order < ApplicationRecord
  PRIORITIES = %w[standard express].freeze
  SERVICES = %w[gift_wrap insurance signature].freeze

  belongs_to :customer
  has_many :items, class_name: "OrderItem", inverse_of: :order, dependent: :destroy
  accepts_nested_attributes_for :items

  enum :status, { pending: "pending", confirmed: "confirmed", shipped: "shipped",
                  delivered: "delivered", cancelled: "cancelled" }

  before_validation :assign_code, on: :create

  validates :code, presence: true, uniqueness: true
  validates :delivery_on, presence: true
  validates :items, presence: true

  def self.build_from_contract(attrs)
    attrs = attrs.to_h.stringify_keys
    customer_attrs = attrs.delete("customer")
    new(attrs).tap { |order| order.customer = Customer.new(customer_attrs) if customer_attrs }
  end

  def total
    items.sum(BigDecimal("0")) { |item| item.quantity.to_i * item.unit_price.to_d }
  end

  private

  def assign_code
    self.code ||= "ORD-#{SecureRandom.hex(4).upcase}"
  end
end
