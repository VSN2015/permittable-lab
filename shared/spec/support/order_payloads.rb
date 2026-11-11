# Payloads for the Tao don form. form_params is what a browser posts;
# contract_output is the expected permitted_params, written by hand from the
# README rules (never copied from a run).
module OrderPayloads
  module_function

  def form_params(overrides = {})
    order = {
      "customer" => { "name" => "Nguyen Van A", "email" => "ana@example.com", "phone" => "0901234567" },
      "shipping_address" => { "line1" => "1 Le Loi", "city" => "Ho Chi Minh", "postcode" => "700000" },
      "delivery_on(1i)" => "2030", "delivery_on(2i)" => "1", "delivery_on(3i)" => "15",
      "pickup_at(1i)" => "", "pickup_at(2i)" => "", "pickup_at(3i)" => "",
      "pickup_at(4i)" => "", "pickup_at(5i)" => "",
      "delivery_slot(1i)" => "1", "delivery_slot(2i)" => "1", "delivery_slot(3i)" => "1",
      "delivery_slot(4i)" => "", "delivery_slot(5i)" => "",
      "priority" => "standard",
      "coupon_code" => "",
      "note" => "",
      "services" => ["", "gift_wrap"],
      "items_attributes" => { "0" => { "sku" => "SKU1", "quantity" => "2", "unit_price" => "199.5" } }
    }
    { "order" => deep_merge(order, stringify(overrides)) }
  end

  # README: absent optionals are omitted; "" is absent; priority defaults;
  # note is nullable so "" gives nil; "" elements of services are dropped;
  # date parts are assembled into a Date. An untouched datetime_select
  # (pickup_at, every part blank) reads as absent and is omitted. An untouched
  # time_select (delivery_slot) posts the hidden date 1,1,1 with blank hour and
  # minute: README "Unknown parameters" gives 0001-01-01T00:00:00, which a
  # :datetime casts to a UTC Time.
  def contract_output
    {
      "customer" => { "name" => "Nguyen Van A", "email" => "ana@example.com", "phone" => "0901234567" },
      "shipping_address" => { "line1" => "1 Le Loi", "city" => "Ho Chi Minh", "postcode" => "700000" },
      "delivery_on" => Date.new(2030, 1, 15),
      "delivery_slot" => Time.utc(1, 1, 1, 0, 0, 0),
      "priority" => "standard",
      "note" => nil,
      "services" => ["gift_wrap"],
      "items_attributes" => [{ "sku" => "SKU1", "quantity" => 2, "unit_price" => BigDecimal("199.5") }]
    }
  end

  def stringify(value)
    case value
    when Hash then value.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    else value
    end
  end

  def deep_merge(base, overrides)
    overrides.each do |key, value|
      if value.nil?
        base.delete(key)
      elsif value.is_a?(Hash) && base[key].is_a?(Hash)
        deep_merge(base[key], value)
      else
        base[key] = value
      end
    end
    base
  end
end
