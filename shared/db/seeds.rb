# Idempotent: safe to run any number of times.
customers = [
  ["Nguyen Van An", "an@example.com", "0901000001"],
  ["Tran Thi Binh", "binh@example.com", "0901000002"],
  ["Le Van Cuong", "cuong@example.com", "0901000003"]
].map do |name, email, phone|
  Customer.find_or_create_by!(email: email) { |c| c.assign_attributes(name: name, phone: phone) }
end

orders = [
  ["ORD-SEED0001", "pending",   "standard", 0, [["SKU-001", 1, "10.50"]]],
  ["ORD-SEED0002", "confirmed", "standard", 1, [["SKU-002", 2, "5.00"], ["SKU-003", 1, "7.25"]]],
  ["ORD-SEED0003", "shipped",   "standard", 2, [["SKU-001", 3, "10.50"]]],
  ["ORD-SEED0004", "delivered", "standard", 0, [["SKU-004", 1, "99.99"], ["SKU-002", 1, "5.00"], ["SKU-003", 2, "7.25"]]],
  ["ORD-SEED0005", "cancelled", "standard", 1, [["SKU-005", 1, "20.00"]]],
  ["ORD-SEED0006", "pending",   "express",  2, [["SKU-006", 2, "15.00"]]]
]

orders.each_with_index do |(code, status, priority, customer_index, items), index|
  Order.find_or_create_by!(code: code) do |order|
    order.customer = customers[customer_index]
    order.status = status
    order.priority = priority
    order.delivery_on = Date.new(2030, 1, 1) + index
    order.services = priority == "express" ? %w[signature] : []
    order.shipping_address = { "line1" => "#{index + 1} Le Loi", "city" => "Ho Chi Minh", "postcode" => "700000" }
    items.each do |sku, quantity, unit_price|
      order.items.build(sku: sku, quantity: quantity, unit_price: unit_price)
    end
  end
end
