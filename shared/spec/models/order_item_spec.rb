require "spec_helper"

RSpec.describe OrderItem do
  def item(quantity)
    OrderItem.new(order: Order.new, sku: "SKU-1", quantity: quantity, unit_price: 1)
  end

  it "accepts an integer quantity >= 1" do
    expect(item(1)).to be_valid
  end

  it "rejects zero, negatives and non-integers" do
    [0, -1, 1.5].each do |q|
      expect(item(q)).not_to be_valid
    end
  end

  it "requires a quantity" do
    expect(item(nil)).not_to be_valid
  end
end
