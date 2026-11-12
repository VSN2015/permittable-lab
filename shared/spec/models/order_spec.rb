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
    expect(order).to be_pending
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
        "shipping_address" => { "line1" => "1 Main", "city" => "HCM", "postcode" => "70000" },
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

  # README: Field options (in: takes a Hash)
  describe "cancel_reason" do
    it "maps cancel reasons to integers" do
      expect(Order.cancel_reasons).to eq({ "changed_mind" => 0, "wrong_address" => 1, "out_of_stock" => 2, "other" => 3 })
      expect(Order.cancel_reasons.keys).not_to eq Order.cancel_reasons.values
    end

    it "closed? is true for delivered and cancelled only" do
      closed = Order.statuses.keys.to_h { |s| [s, Order.new(status: s).closed?] }
      expect(closed).to eq({ "pending" => false, "confirmed" => false, "shipped" => false,
                             "delivered" => true, "cancelled" => true })
    end

    it "stores a cancel reason by key" do
      order = build_order.tap(&:save!)
      order.update!(status: "cancelled", cancel_reason: "wrong_address")
      expect(order.read_attribute_before_type_cast("cancel_reason")).to eq 1
    end
  end
end
