# README: Field options (in:, default:, transform:); Output reshaping (transform: and finalize); Custom error messages (message:); Unknown parameters (path parameters); Reusing fields
RSpec.describe "Doi trang thai (change status)", type: :request, since: "0.12.0",
  covers: %w[opt-in-enum-hash opt-default-as-authored-with-transform finalize-basic finalize-violate msg-violate-keyword unknown-exempt-path-params use-contract unknown-exempt-form-keys unknown-exempt-csrf unknown-exempt-commit unknown-exempt-button] do
  before { Inspector::Store.clear }

  def doc
    Nokogiri::HTML(response.body)
  end

  def violation(param, code)
    doc.css(%(li[data-param="#{param}"][data-code="#{code}"]))
  end

  def pairs
    doc.css("li[data-param][data-code]").map { |li| [li["data-param"], li["data-code"]] }
  end

  def change(order, hash, locale: "vi")
    patch order_status_path(order, locale: locale), params: hash
  end

  def make(**attrs)
    OrderPayloads.create_order(**attrs)
  end

  def events(&block)
    collected = []
    ActiveSupport::Notifications.subscribed(->(*args) { collected << args.last }, "invalid_parameters.permittable", &block)
    collected
  end

  it "accepts a status change", covers: %w[use-contract unknown-exempt-path-params finalize-basic] do
    order = make
    change(order, { "status" => "shipped" })
    expect(response).to have_http_status(303)
    order.reload
    expect([order.status, order.remind_after]).to eq ["shipped", 1800]
    expect(Inspector::Store.latest.permitted).to eq("status" => "shipped", "remind_after" => 1800)
    expect(Inspector::Store.latest.permitted["remind_after"]).to be_an(Integer)
    expect(request.query_parameters["locale"]).to eq "vi"
  end

  [["_method", "patch"], ["utf8", "✓"], ["authenticity_token", "x"], ["commit", "Cập nhật trạng thái"], ["button", ""]].each do |key, value|
    covers = { "_method" => "unknown-exempt-form-keys", "utf8" => "unknown-exempt-form-keys", "authenticity_token" => "unknown-exempt-csrf",
               "commit" => "unknown-exempt-commit", "button" => "unknown-exempt-button" }.fetch(key)
    it "tolerates the #{key} key Rails adds to a form post", covers: [covers] do
      order = make
      change(order, { "status" => "shipped", key => value })
      expect(response).to have_http_status(303)
      expect(Inspector::Store.latest.permitted.keys).to eq %w[status remind_after]
      expect(order.reload.status).to eq "shipped"

      other = make
      change(other, { "status" => "shipped", "not_exempt" => "1", key => value })
      expect(response).to have_http_status(422)
      expect(doc.css("li[data-param][data-code]").map { |li| li["data-param"] }).to eq ["not_exempt"]
      expect(other.reload.status).to eq "pending"
    end
  end

  it "only an undeclared key is unknown, never the path id", covers: %w[unknown-exempt-path-params] do
    change(make, { "status" => "shipped", "bogus" => "1" })
    expect(response).to have_http_status(422)
    expect(doc.css("li[data-param]").map { |li| li["data-param"] }).to eq ["bogus"]
    expect(violation("bogus", "unknown").size).to eq 1
  end

  it "in: Order.statuses is read as its keys", covers: %w[opt-in-enum-hash] do
    (Order.statuses.keys - %w[cancelled]).each do |status|
      change(make, { "status" => status })
      expect(response).to have_http_status(303)
    end
    change(make, { "status" => "lost" })
    expect(response).to have_http_status(422)
    expect(violation("status", "inclusion").size).to eq 1
    Order.cancel_reasons.each_key do |reason|
      order = make
      change(order, { "status" => "cancelled", "cancel_reason" => reason })
      expect(response).to have_http_status(303)
      expect(order.reload.cancel_reason).to eq reason
    end
    change(make, { "status" => "cancelled", "cancel_reason" => "1" })
    expect(response).to have_http_status(422)
    expect(violation("cancel_reason", "inclusion").size).to eq 1
  end

  it "remind_after: default as authored, transform on sent values", covers: %w[opt-default-as-authored-with-transform] do
    order = make
    change(order, { "status" => "shipped" })
    expect(Inspector::Store.latest.permitted["remind_after"]).to eql 1800
    expect(order.reload.remind_after).to eq 1800
    change(order, { "status" => "shipped", "remind_after" => "45" })
    expect(Inspector::Store.latest.permitted["remind_after"]).to eql 2700
    expect(order.reload.remind_after).to eq 2700
    %w[99999 -5].each do |bad|
      change(make, { "status" => "shipped", "remind_after" => bad })
      expect(response).to have_http_status(422)
      expect(violation("remind_after", "format").size).to eq 1
    end
  end

  it "finalize is not run while a field is invalid", covers: %w[finalize-basic] do
    change(make, { "status" => "cancelled", "remind_after" => "abc" })
    expect(response).to have_http_status(422)
    expect(pairs).to eq [["remind_after", "format"]]
  end

  it "cancelling needs a reason", covers: %w[finalize-violate msg-violate-keyword] do
    order = make
    change(order, { "status" => "cancelled" })
    expect(response).to have_http_status(422)
    expect(violation("cancel_reason", "required_when_cancelled").text).to eq "bắt buộc khi trạng thái là Đã huỷ"
    expect(order.reload.status).to eq "pending"
    change(order, { "status" => "cancelled" }, locale: "en")
    expect(response).to have_http_status(422)
    expect(violation("cancel_reason", "required_when_cancelled").text).to eq "is required when the status is cancelled"
    change(order, { "status" => "cancelled", "cancel_reason" => "wrong_address" })
    expect(response).to have_http_status(303)
    order.reload
    expect([order.status, order.cancel_reason]).to eq %w[cancelled wrong_address]
    other = make
    change(other, { "status" => "shipped", "cancel_reason" => "other" })
    expect(response).to have_http_status(422)
    expect(violation("cancel_reason", "only_when_cancelled").text).to eq "chỉ dùng khi trạng thái là Đã huỷ"
    expect(other.reload.status).to eq "pending"
  end

  it "closed orders are terminal" do
    order = make(status: "cancelled")
    seen = events do
      [{ "status" => "shipped" }, { "status" => "lost" }].each do |payload|
        change(order, payload)
        expect(response).to have_http_status(303)
        follow_redirect!
        expect(doc.css("#flash-alert").text).to eq "Đơn đã đóng, không thể thay đổi"
        expect(order.reload.status).to eq "cancelled"
      end
    end
    expect(seen).to be_empty
  end

  it "survives hostile input" do
    order = make
    change(order, { "status" => ["shipped"] })
    expect(response).to have_http_status(422)
    expect(violation("status", "invalid_type").size).to eq 1
    change(order, {})
    expect(response).to have_http_status(422)
    expect(violation("status", "missing").size).to eq 1
  end

  it "treats locale on a rootless contract as a declared string" do
    order = make
    patch "#{order_status_path(order)}?locale=xx", params: { "status" => "shipped" }
    expect(response).to have_http_status(303)
    expect(order.reload.status).to eq "shipped"
    patch "#{order_status_path(make)}?locale[]=vi", params: { "status" => "shipped" }
    expect(response).to have_http_status(422)
    expect(violation("locale", "invalid_type").size).to eq 1
    expect(doc.css("html").first["lang"]).to eq "vi"
  end

  it "answers 404 for an unknown id without events" do
    seen = events do
      patch order_status_path(0), params: { "status" => "shipped" }
      expect(response).to have_http_status(404)
    end
    expect(seen).to be_empty
  end
end
