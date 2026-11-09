# README: Declaring a contract; Unknown parameters; Violations and error responses; Localizing default messages (I18n)
RSpec.describe "Tao don (create order)", type: :request, since: "0.12.0",
  covers: %w[pp-root pp-model pp-unknown pp-enforce-true kind-nested kind-array-hash kind-array-fields-for-hash kind-array-scalar kind-scalar opt-in-range opt-in-list opt-format-regexp opt-length-string opt-length-array opt-default-cast opt-normalize-squish opt-normalize-email opt-nullable preset-email type-integer type-decimal type-date type-datetime absent-blank-array-element absent-nullable-normalize-blank absent-optional-omitted absent-required-missing absent-default err-code-missing err-code-invalid-type err-code-inclusion err-code-format err-code-length err-code-unknown err-status-400-root-missing err-status-400-root-wrong-shape err-status-422-field err-path-dotted-indexed err-render-error-custom err-render-error-private i18n-default-messages i18n-per-request-locale unknown-error unknown-every-level date-select-parts datetime-select-parts time-select-parts date-parts-blank date-parts-invalid use-group] do
  def doc
    Nokogiri::HTML(response.body)
  end

  def violation(param, code)
    doc.css(%(li[data-param="#{param}"][data-code="#{code}"]))
  end

  def valid(overrides = {})
    OrderPayloads.form_params(overrides)
  end

  it "renders the form with the field names a browser posts" do
    get new_order_path
    expect(response).to have_http_status(200)
    expect(doc.css(%(input[name="order[items_attributes][0][quantity]"]))).not_to be_empty
    expect(doc.css(%(select[name="order[delivery_on(1i)]"]))).not_to be_empty
    expect(doc.css(%(input[type=checkbox][name="order[services][]"]))).not_to be_empty
    expect(doc.css(%(input[type=hidden][name="order[services][]"]))[0]["value"]).to eq ""
    %w[customer shipping_address].zip([%w[name email phone], %w[line1 city postcode]]).each do |group, keys|
      keys.each { |k| expect(doc.css(%(input[name="order[#{group}][#{k}]"]))).not_to be_empty }
    end
    expect(doc.css(%(select[name="order[pickup_at(4i)]"]))).not_to be_empty
    expect(doc.css(%(select[name="order[delivery_slot(4i)]"]))).not_to be_empty
    expect(doc.css("input[type=submit]").size).to eq 1
    expect(doc.css("button[type=submit]").size).to eq 1
    expect(doc.css(%(a#locale-vi))[0].text).to eq "Tiếng Việt"
    expect(doc.css(%(a#locale-en))[0].text).to eq "English"
  end

  it "accepts a valid form post" do
    params = valid("customer" => { "name" => "  Nguyễn   Văn A ", "email" => " Ana@Example.COM " })
    expect { post orders_path, params: params }.to change(Order, :count).by(1)
    order = Order.last
    expect(response).to have_http_status(303)
    expect(URI(response.location).path).to eq order_path(order)
    expect(Rack::Utils.parse_query(URI(response.location).query)).to eq("locale" => "vi")
    expect(order.customer.name).to eq "Nguyễn Văn A"
    expect(order.customer.email).to eq "ana@example.com"
    expect(order.priority).to eq "standard"
    expect(order.status).to eq "pending"
    expect(order.note).to be_nil
    expect(order.services).to eq ["gift_wrap"]
    expect(order.delivery_on).to be_a(Date)
    expect(order.items.first.quantity).to eq 2
    expect(order.items.first.quantity).to be_an(Integer)
    expect(order.items.first.unit_price).to eq BigDecimal("199.5")
  end

  it "reads datetime_select and time_select parts" do
    params = valid("pickup_at(1i)" => "2030", "pickup_at(2i)" => "2", "pickup_at(3i)" => "3",
                   "pickup_at(4i)" => "9", "pickup_at(5i)" => "30",
                   "delivery_slot(1i)" => "2000", "delivery_slot(2i)" => "1", "delivery_slot(3i)" => "1",
                   "delivery_slot(4i)" => "14", "delivery_slot(5i)" => "45")
    post orders_path, params: params
    expect(response).to have_http_status(303)
    order = Order.last
    expect(order.pickup_at.utc).to eq Time.utc(2030, 2, 3, 9, 30)
    expect(order.delivery_slot.utc.strftime("%H:%M")).to eq "14:45"
  end

  it "treats whitespace-only note as nil and an all-unchecked services as accepted" do
    post orders_path, params: valid("note" => "   ", "services" => [""])
    expect(response).to have_http_status(303)
    expect(Order.last.note).to be_nil
    expect(Order.last.services).to eq []
  end

  it "does not break on the keys the form adds (commit, button)" do
    post orders_path, params: valid.merge("commit" => "Tạo đơn")
    expect(response).to have_http_status(303)
    post orders_path, params: valid.merge("commit" => "Tạo đơn", "button" => "")
    expect(response).to have_http_status(303)
  end

  describe "violations" do
    [
      ["order.customer.email", "format", { "customer" => { "email" => "not-an-email" } }],
      ["order.customer.name", "missing", { "customer" => { "name" => "" } }],
      ["order.customer.phone", "length", { "customer" => { "phone" => "12" } }],
      ["order.items_attributes[0].quantity", "inclusion", { "items_attributes" => { "0" => { "quantity" => "0" } } }],
      ["order.items_attributes[0].quantity", "invalid_type", { "items_attributes" => { "0" => { "quantity" => "abc" } } }],
      ["order.items_attributes[0].unit_price", "inclusion", { "items_attributes" => { "0" => { "unit_price" => "-1" } } }],
      ["order.coupon_code", "format", { "coupon_code" => "abc" }],
      ["order.priority", "inclusion", { "priority" => "overnight" }],
      ["order.note", "length", { "note" => "x" * 201 }],
      ["order.services", "length", { "services" => ["", "gift_wrap", "insurance", "signature", "gift_wrap"] }],
      ["order.shipping_address.city", "missing", { "shipping_address" => { "city" => "" } }],
      ["order.delivery_on", "missing", { "delivery_on(2i)" => "" }],
      ["order.delivery_on", "invalid_type", { "delivery_on(2i)" => "2", "delivery_on(3i)" => "30" }]
    ].each do |param, code, overrides|
      it "#{param} #{code} for #{overrides.inspect[0, 60]}" do
        expect { post orders_path, params: valid(overrides) }.not_to change(Order, :count)
        expect(response).to have_http_status(422)
        expect(violation(param, code).size).to eq 1
      end
    end
  end

  describe "mass assignment" do
    {
      "order.status" => { "status" => "delivered" },
      "order.code" => { "code" => "X" },
      "order.customer_id" => { "customer_id" => "1" },
      "order.customer.admin" => { "customer" => { "admin" => "1" } }
    }.each do |param, overrides|
      it "rejects #{param} as unknown" do
        expect { post orders_path, params: valid(overrides) }.not_to change { [Order.count, Customer.count] }
        expect(response).to have_http_status(422)
        expect(violation(param, "unknown").size).to eq 1
      end
    end
  end

  describe "bad root" do
    it "is 400 and re-renders the form when order is absent" do
      post orders_path
      expect(response).to have_http_status(400)
      expect(doc.css("form[action]")).not_to be_empty
      expect(violation("order", "missing").size).to eq 1
    end

    it "is 400 when order is a scalar" do
      post orders_path, params: { order: "bob" }
      expect(response).to have_http_status(400)
      expect(doc.css("form[action]")).not_to be_empty
      expect(violation("order", "invalid_type").size).to eq 1
    end
  end

  it "rejects 21 item rows with a single length violation" do
    items = (0..20).to_h { |i| [i.to_s, { "sku" => "S#{i}", "quantity" => "1", "unit_price" => "1" }] }
    expect { post orders_path, params: valid("items_attributes" => items) }.not_to change(Order, :count)
    expect(response).to have_http_status(422)
    expect(doc.css("li[data-param]").size).to eq 1
    expect(violation("order.items_attributes", "length").size).to eq 1
  end

  describe "locale" do
    let(:no_name) { valid("customer" => { "name" => "" }) }

    it "answers in Vietnamese for locale=vi" do
      post orders_path(locale: "vi"), params: no_name
      expect(response).to have_http_status(422)
      expect(violation("order.customer.name", "missing").text).to eq "là bắt buộc"
    end

    it "answers in English for locale=en (enforce path plus prepend_around_action)" do
      post orders_path(locale: "en"), params: no_name
      expect(response).to have_http_status(422)
      expect(violation("order.customer.name", "missing").text).to eq "is required"
    end

    [{ "locale" => "xx" }, { "locale" => "" }].each do |q|
      it "falls back to Vietnamese for #{q.inspect}" do
        post "/orders?#{q.to_query}", params: no_name
        expect(response).to have_http_status(422)
        expect(violation("order.customer.name", "missing").text).to eq "là bắt buộc"
      end
    end

    it "falls back to Vietnamese for locale[]=vi" do
      post "/orders?locale[]=vi", params: no_name
      expect(response).to have_http_status(422)
      expect(violation("order.customer.name", "missing").text).to eq "là bắt buộc"
    end
  end

  describe "CSRF" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it "accepts the post with the real token" do
      get new_order_path
      token = doc.css(%(input[name="authenticity_token"]))[0]["value"]
      expect { post orders_path, params: valid.merge("authenticity_token" => token, "commit" => "Tạo đơn") }
        .to change(Order, :count).by(1)
      expect(response).to have_http_status(303)
    end

    it "creates no order without the token" do
      expect { post orders_path, params: valid }.not_to change(Order, :count)
    end
  end

  describe "pages" do
    before { Rails.application.load_seed }

    it "lists seeded orders with code and total" do
      get orders_path
      expect(response).to have_http_status(200)
      expect(response.body).to include("ORD-SEED0002")
      row = doc.css("tr").find { |tr| tr.text.include?("ORD-SEED0002") }
      expect(row.css("td.total").text).to eq "17.25"
    end

    it "shows an order's items" do
      get order_path(Order.find_by!(code: "ORD-SEED0004"))
      expect(response).to have_http_status(200)
      expect(doc.css("td.sku").map(&:text)).to match_array(%w[SKU-004 SKU-002 SKU-003])
    end

    it "is 404 for an unknown id" do
      get order_path(0)
      expect(response).to have_http_status(404)
    end
  end
end
