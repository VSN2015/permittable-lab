# README: Instrumentation; Sensitive parameters and log redaction
RSpec.describe "Inspector panel", type: :request, since: "0.12.0",
  covers: %w[opt-sensitive event-payload] do
  before { Inspector::Store.clear }
  after { Inspector::Store.clear }

  def panel
    Nokogiri::HTML(response.body)
  end

  def section(id)
    panel.css("##{id}")
  end

  def invalid_post(overrides = { "customer" => { "email" => "nope" } })
    post orders_path, params: OrderPayloads.form_params(overrides)
  end

  it "shows a valid post: status, verbatim raw params, permitted" do
    post orders_path, params: OrderPayloads.form_params
    expect(response).to have_http_status(303)
    get "/inspector/last"
    expect(response).to have_http_status(200)
    expect(section("inspector-status").text).to include("303")
    raw = Inspector::Store.latest.raw_params
    expect(raw).to include(["order[delivery_on(1i)]", "2030"])
    expect(raw).to include(["order[services][]", ""])
    expect(raw).to include(["order[customer][phone]", "0901234567"])
    expect(section("inspector-raw-params").text).to include("order[delivery_on(1i)]")
    expect(section("inspector-raw-params").text).to include("order[services][]")
    expect(section("inspector-raw-params").text).to include("0901234567")
    expect(section("inspector-permitted").text).to include("delivery_on")
  end

  it "shows a rejection: violations, event, config" do
    invalid_post
    expect(response).to have_http_status(422)
    get "/inspector/last"
    expect(section("inspector-status").text).to include("422")
    expect(section("inspector-permitted").text).to include("Bị từ chối")
    row = section("inspector-violations").css("tr").find { |tr| tr.text.include?("order.customer.email") }
    expect(row).not_to be_nil
    expect(row.text).to include("format")
    expect(row.text).to include("sai định dạng")
    expect(section("inspector-events").text).to include("enforce")
    expect(section("inspector-config").text).to include("envelope")
    expect(section("inspector-config").text).to include("enforce")
    expect(Inspector::Store.latest.rejected).to be true
  end

  it "shows Rejected in English" do
    invalid_post
    get "/inspector/last", params: { locale: "en" }
    expect(section("inspector-permitted").text).to include("Rejected")
  end

  it "does not change the response or the event count" do
    payloads = []
    sub = ActiveSupport::Notifications.subscribe("invalid_parameters.permittable") { |*, payload| payloads << payload }
    invalid_post
    expect(payloads.size).to eq 1
    # README Instrumentation: controller "users", action "create", mode :enforce, details [{ param:, code: }]
    payload = payloads.first
    expect(payload[:controller]).to eq "orders"
    expect(payload[:action]).to eq "create"
    expect(payload[:mode]).to eq :enforce
    detail = payload[:details].find { |d| d[:param] == "order.customer.email" }
    expect(detail).not_to be_nil
    expect(detail[:code].to_s).to eq "format"
    expect(response).to have_http_status(422)
    expect(response.body).to include("sai định dạng")
    expect(panel.css("li[data-param='order.customer.email'][data-code='format']")).not_to be_empty
    expect(Inspector::Store.latest.events.size).to eq 1
  ensure
    ActiveSupport::Notifications.unsubscribe(sub) if sub
  end

  it "shows the filtered Rails log line, not the raw phone" do
    post orders_path, params: OrderPayloads.form_params
    get "/inspector/last"
    log = section("inspector-log").text
    expect(log).to include("Parameters:")
    expect(log).to match(/"phone"\s*=>\s*"\[FILTERED\]"/)
    expect(log).not_to include("0901234567")
  end

  describe "hostile input" do
    it "escapes markup" do
      post orders_path, params: OrderPayloads.form_params("note" => "<script>alert(1)</script>")
      get "/inspector/last"
      expect(response.body).to include("&lt;script&gt;")
      expect(panel.css("script")).to be_empty
    end

    it "cuts a 10,000 character value to 1,000 plus a marker" do
      post orders_path, params: OrderPayloads.form_params("note" => "a" * 10_000)
      get "/inspector/last"
      cell = section("inspector-raw-params").css("td").find { |td| td.text.start_with?("a" * 50) }
      expect(cell.text).to eq("a" * 1000 + "... (9000 more characters)")
    end

    it "passes an invalid UTF-8 body through and still renders the panel" do
      post orders_path, params: "order[note]=%FF", headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
      expect(response).to have_http_status(400)
      get "/inspector/last"
      expect(response).to have_http_status(200)
      expect(section("inspector-raw-params").text).to include("(unparseable)")
    end
  end

  it "keeps the last tracked POST when a GET comes after" do
    invalid_post
    get new_order_path
    get "/inspector/last"
    expect(section("inspector-status").text).to include("422")
    expect(section("inspector-status").text).to include("POST")
  end

  it "finds an entry by request id" do
    invalid_post
    id = Inspector::Store.latest.request_id
    post orders_path, params: OrderPayloads.form_params
    get "/inspector/last", params: { entry: id }
    expect(section("inspector-status").text).to include("422")
  end

  it "frames the panel in the layout" do
    get new_order_path
    frame = Nokogiri::HTML(response.body).css("iframe#inspector-frame").first
    expect(frame["src"]).to eq "/inspector/last"
  end
end
