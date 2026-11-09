require "spec_helper"

RSpec.describe Order do
  let(:customer) { Customer.create!(name: "An", email: "an@example.com") }

  def build_order(items: [{ sku: "A", quantity: 1, unit_price: "1.00" }])
    Order.new(customer: customer, delivery_on: Date.new(2030, 1, 2),
              items_attributes: items)
  end

  it "saves a valid order" do
    expect(build_order.save).to be true
  end

  it "assigns a unique ORD- code" do
    a = build_order.tap(&:save!)
    b = build_order.tap(&:save!)
    expect(a.code).to match(/\AORD-[0-9A-F]{8}\z/)
    expect(a.code).not_to eq b.code
  end

  it "defaults status to pending" do
    order = build_order
    expect(order.status).to eq "pending"
    expect(Order.statuses.keys).to include("pending")
  end

  it "is invalid without items" do
    expect(build_order(items: [])).not_to be_valid
  end

  it "sums quantity * unit_price" do
    order = build_order(items: [{ sku: "A", quantity: 2, unit_price: "10.50" },
                                { sku: "B", quantity: 1, unit_price: "3.00" }])
    expect(order.total).to eq BigDecimal("24.00")
    expect(order.total).to be_a(BigDecimal)
  end

  describe ".build_from_contract" do
    let(:attrs) do
      {
        "customer" => { "name" => "Binh", "email" => "b@example.com", "phone" => "0900" },
        "shipping_address" => { "street" => "1 Main", "city" => "HCM" },
        "delivery_on" => Date.new(2030, 1, 2),
        "services" => %w[gift_wrap],
        "items_attributes" => [
          { "sku" => "A", "quantity" => 2, "unit_price" => "10.50" },
          { "sku" => "B", "quantity" => 1, "unit_price" => "3.00" }
        ]
      }
    end

    it "builds an unsaved order with customer and items" do
      order = Order.build_from_contract(attrs)
      expect(order).to be_new_record
      expect(order.customer.name).to eq "Binh"
      expect(order.customer).to be_new_record
      expect(order.items.size).to eq 2
      expect(order.shipping_address["city"]).to eq "HCM"
    end

    it "never touches customer_attributes" do
      order = Order.build_from_contract(attrs)
      expect(order.customer.email).to eq "b@example.com"
      expect(Order.nested_attributes_options).not_to have_key(:customer)
    end
  end
end
