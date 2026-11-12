# README: How a request flows; Absence, defaults, and partial updates; Reusing fields; Instrumentation; Types and strict coercion
RSpec.describe "Sua don (edit order)", type: :request, since: "0.12.0",
  covers: %w[pp-enforce-lazy pp-last-rule-wins use-compose use-optional absent-optional-omitted event-once-per-request type-date type-datetime] do
  before { Inspector::Store.clear }

  def doc
    Nokogiri::HTML(response.body)
  end

  def violation(param, code)
    doc.css(%(li[data-param="#{param}"][data-code="#{code}"]))
  end

  def patch_order(order, hash)
    patch order_path(order, locale: "vi"), params: { "order" => hash }
  end

  def events(&block)
    collected = []
    ActiveSupport::Notifications.subscribed(->(*args) { collected << args.last }, "invalid_parameters.permittable", &block)
    collected
  end

  def make(**attrs)
    OrderPayloads.create_order(**attrs)
  end

  it "renders the edit form prefilled" do
    order = make(priority: "express", note: "keep", services: %w[gift_wrap], delivery_on: Date.new(2030, 1, 15))
    %w[vi en].each do |locale|
      get edit_order_path(order, locale: locale)
      expect(response).to have_http_status(200)
      expect(response.body).not_to match(/translation[ _]missing/i)
    end
    get edit_order_path(order, locale: "vi")
    expect(doc.css(%(input[name="_method"]))[0]["value"]).to eq "patch"
    expect(doc.css(%(textarea[name="order[note]"]))[0].text.strip).to eq "keep"
    expect(doc.css(%(select[name="order[priority]"] option[selected]))[0]["value"]).to eq "express"
    expect(doc.css(%(input[type=checkbox][name="order[services][]"][value=gift_wrap]))[0]["checked"]).not_to be_nil
    expect(doc.css(%(input[type=checkbox][name="order[services][]"][value=insurance]))[0]["checked"]).to be_nil
    expect(doc.css(%q(select[name="order[delivery_on(1i)]"] option[selected]))[0]["value"]).to eq "2030"
    expect(doc.css(%(input[name="order[shipping_address][line1]"]))[0]["value"]).to eq "1 Le Loi"
    expect(doc.css(%(input[name="order[shipping_address][city]"]))[0]["value"]).to eq "Ho Chi Minh"
    expect(doc.css(%(input[name="order[shipping_address][postcode]"]))[0]["value"]).to eq "700000"
    expect(doc.css(%q([name^="order[pickup_at"], [name^="order[delivery_slot"]))).to be_empty
  end

  it "updates only what is sent", covers: %w[absent-optional-omitted use-optional] do
    order = make(priority: "express", coupon_code: "ABC123", note: "keep", delivery_on: Date.new(2030, 1, 15))
    patch_order(order, "note" => "new")
    expect(response).to have_http_status(303)
    expect(URI(response.location).path).to eq order_path(order)
    order.reload
    expect([order.note, order.priority, order.coupon_code, order.delivery_on]).to eq ["new", "express", "ABC123", Date.new(2030, 1, 15)]
    expect(Inspector::Store.latest.permitted).to eq("note" => "new")
  end

  it "an empty optional never clears a column, an empty nullable one does" do
    order = make(coupon_code: "ABC123", note: "keep")
    patch_order(order, "coupon_code" => "")
    expect(response).to have_http_status(303)
    expect(order.reload.coupon_code).to eq "ABC123"
    expect(Inspector::Store.latest.permitted).not_to have_key("coupon_code")
    patch_order(order, "note" => "")
    expect(response).to have_http_status(303)
    expect(order.reload.note).to be_nil
    expect(Inspector::Store.latest.permitted).to eq("note" => nil)
  end

  it "keeps bounds and the address's own requirements", covers: %w[use-optional] do
    order = make(note: "keep")
    patch_order(order, "priority" => "bogus")
    expect(response).to have_http_status(422)
    expect(violation("order.priority", "inclusion").size).to eq 1
    patch_order(order, "shipping_address" => { "city" => "Hue" })
    expect(response).to have_http_status(422)
    expect(violation("order.shipping_address.line1", "missing").size).to eq 1
    expect(violation("order.shipping_address.postcode", "missing").size).to eq 1
    expect(order.reload.shipping_address).to eq("line1" => "1 Le Loi", "city" => "Ho Chi Minh", "postcode" => "700000")
    expect(order.priority).to eq "standard"
  end

  it "composes the groups", covers: %w[use-compose] do
    order = make
    patch_order(order, "priority" => "express", "coupon_code" => "XYZ123", "note" => "  hi   there ",
                       "services" => ["", "insurance"],
                       "shipping_address" => { "line1" => "2 Hai Ba Trung", "city" => "Hue", "postcode" => "530000" })
    expect(response).to have_http_status(303)
    order.reload
    expect([order.priority, order.coupon_code, order.note, order.services]).to eq ["express", "XYZ123", "hi there", ["insurance"]]
    expect(order.shipping_address).to eq("line1" => "2 Hai Ba Trung", "city" => "Hue", "postcode" => "530000")
    address = { "line1" => "2 Hai Ba Trung", "city" => "Hue", "postcode" => "530000" }
    [
      ["order.coupon_code", "format", { "coupon_code" => "abc" }],
      ["order.services", "length", { "services" => %w[gift_wrap insurance signature gift_wrap] }],
      ["order.shipping_address.postcode", "length", { "shipping_address" => address.merge("postcode" => "1") }]
    ].each do |param, code, payload|
      patch_order(order, payload)
      expect(response).to have_http_status(422)
      expect(violation(param, code).size).to eq 1
    end
  end

  describe "mass assignment is refused" do
    [
      ["status", "delivered"], ["cancel_reason", "other"], ["code", "X"], ["id", "99"],
      ["customer", { "name" => "x" }]
    ].each do |key, value|
      it key do
        order = make
        expect { patch_order(order, key => value) }.not_to change { order.reload.attributes }
        expect(response).to have_http_status(422)
        expect(violation("order.#{key}", "unknown").size).to eq 1
      end
    end
  end

  it "the last matching rule wins over a catch-all", covers: %w[pp-last-rule-wins] do
    patch_order(make, "note" => "ok")
    expect(response).to have_http_status(303)
  end

  it "is lazy", covers: %w[pp-enforce-lazy] do
    payload = { "coupon_code" => "abc" }
    delivered = make(status: "delivered")
    seen = events { patch_order(delivered, payload) }
    expect(response).to have_http_status(303)
    expect(URI(response.location).path).to eq order_path(delivered)
    follow_redirect!
    expect(doc.css("#flash-alert")).not_to be_empty
    expect(seen).to be_empty
    expect(Inspector::Store.latest&.rejected).not_to eq true
    expect(Inspector::Store.latest&.permitted).to be_nil
    patch_order(delivered, "note" => "changed")
    expect(response).to have_http_status(303)
    expect(delivered.reload.note).to be_nil

    seen = events { patch_order(make, payload) }
    expect(response).to have_http_status(422)
    expect(violation("order.coupon_code", "format").size).to eq 1
    expect(seen.size).to eq 1
  end

  it "redirects the edit form of a closed order" do
    order = make(status: "delivered")
    get edit_order_path(order, locale: "vi")
    expect(response).to have_http_status(303)
    expect(URI(response.location).path).to eq order_path(order)
    follow_redirect!
    expect(doc.css("#flash-alert").text).to eq "Đơn đã đóng, không thể thay đổi"
  end

  it "announces the attempted fields on success" do
    order = make
    patch_order(order, "note" => "n", "priority" => "express")
    expect(response).to have_http_status(303)
    follow_redirect!
    text = doc.css("#flash-notice").text
    expect(text).to start_with("Đã cập nhật: ")
    expect(text.delete_prefix("Đã cập nhật: ").split(", ").sort).to eq %w[note priority]
  end

  it "instruments a rejection once however often the params are read", covers: %w[event-once-per-request] do
    reads = 0
    allow_any_instance_of(OrdersController).to receive(:permitted_params).and_wrap_original { |m, *a| reads += 1; m.call(*a) }
    seen = events { patch_order(make, "coupon_code" => "abc") }
    expect(reads).to be >= 2
    expect(seen.size).to eq 1
    expect(seen[0][:controller]).to eq "orders"
    expect(seen[0][:action]).to eq "update"
    expect(seen[0][:mode]).to eq :enforce
    expect(seen[0][:details].map { |v| [v[:param], v[:code].to_s] }).to include(["order.coupon_code", "format"])
    expect(Inspector::Store.latest.events.size).to eq 1
    expect(response).to have_http_status(422)
    expect(violation("order.coupon_code", "format").size).to eq 1
  end

  describe "bad root" do
    it "is 400 and shows the edit form" do
      order = make
      [{}, { "order" => "bob" }].each do |params|
        patch order_path(order, locale: "vi"), params: params
        expect(response).to have_http_status(400)
        expect(doc.css(%(form input[name="_method"][value="patch"]))).not_to be_empty
        expect(doc.css("li[data-param][data-code]")).not_to be_empty
      end
    end
  end

  it "answers 404 for an unknown id without events" do
    seen = events do
      get edit_order_path(0)
      expect(response).to have_http_status(404)
      patch order_path(0), params: { "order" => { "note" => "x" } }
      expect(response).to have_http_status(404)
    end
    expect(seen).to be_empty
  end

  # Rails deep-munge control: no gem matcher is called here.
  it "a nil array element sent as JSON is dropped by Rails before the contract", since: "0.14.0" do
    order = make
    patch order_path(order, locale: "vi"), params: { order: { services: ["gift_wrap", nil] } }, as: :json
    expect(response).to have_http_status(303)
    expect(order.reload.services).to eq ["gift_wrap"]
  end

  describe "dates, 0.14.0 rules", since: "0.14.0", covers: %w[type-date type-datetime] do
    %w[2026-09-05 2026-09-05T00:00:00Z 2026-09-05+00:00].each do |literal|
      it "accepts delivery_on #{literal}" do
        order = make
        patch_order(order, "delivery_on" => literal)
        expect(response).to have_http_status(303)
        expect(order.reload.delivery_on).to eq Date.new(2026, 9, 5)
      end
    end

    ["2026-09-05T10:00:00Z", "2026-09-05T00:00:00-05:00", "2026-09-05 -05:00", "2026-09-05 +05:00", "Sep 5 2026 -05:00"].each do |literal|
      it "refuses delivery_on #{literal}" do
        patch_order(make, "delivery_on" => literal)
        expect(response).to have_http_status(422)
        expect(violation("order.delivery_on", "invalid_type").size).to eq 1
      end
    end

    it "stores pickup_at 2026-09-05 -05:00 as UTC" do
      order = make
      patch_order(order, "pickup_at" => "2026-09-05 -05:00")
      expect(response).to have_http_status(303)
      expect(order.reload.pickup_at.utc).to eq Time.utc(2026, 9, 5, 5, 0, 0)
    end

    it "stores pickup_at 2026-09-05 +05:00 as midnight at +05:00" do
      order = make
      patch_order(order, "pickup_at" => "2026-09-05 +05:00")
      expect(response).to have_http_status(303)
      expect(order.reload.pickup_at.utc).to eq Time.utc(2026, 9, 4, 19, 0, 0)
    end

    ["2026-09-05 -0500", "2026-09-05 +5"].each do |literal|
      it "refuses delivery_on #{literal}" do
        patch_order(make, "delivery_on" => literal)
        expect(response).to have_http_status(422)
        expect(violation("order.delivery_on", "invalid_type").size).to eq 1
      end
    end

    ["Sep 5 2026 -05:00", "2026-09-05T"].each do |literal|
      it "refuses pickup_at #{literal}" do
        patch_order(make, "pickup_at" => literal)
        expect(response).to have_http_status(422)
        expect(violation("order.pickup_at", "invalid_type").size).to eq 1
      end
    end
  end

  describe "dates, 0.15.0 rules", since: "0.15.0", covers: %w[type-date type-datetime] do
    it "stores pickup_at 2026-09-05 EST as UTC" do
      order = make
      patch_order(order, "pickup_at" => "2026-09-05 EST")
      expect(response).to have_http_status(303)
      expect(order.reload.pickup_at.utc).to eq Time.utc(2026, 9, 5, 5, 0, 0)
    end

    [["pickup_at", "2026-09-05 XYZ"], ["pickup_at", "2026-09-05 noon"], ["delivery_on", "2026-09-05 EST"]].each do |field, literal|
      it "refuses #{field} #{literal}" do
        patch_order(make, field => literal)
        expect(response).to have_http_status(422)
        expect(violation("order.#{field}", "invalid_type").size).to eq 1
      end
    end
  end
end
