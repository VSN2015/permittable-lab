# README: Unknown parameters; Localizing default messages (I18n)
RSpec.describe "Tạo đơn through the real form (headless Chromium)", type: :system, since: "0.12.0" do
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }

  def fill_form(slot: true)
    fill_in "Họ tên", with: "  Nguyễn   Văn B "
    fill_in "Email", with: " Ben@Example.COM "
    fill_in "Số điện thoại", with: "0901234567"
    fill_in "Địa chỉ", with: "1 Lê Lợi"
    fill_in "Thành phố", with: "Hồ Chí Minh"
    fill_in "Mã bưu chính", with: "700000"
    select "15", from: "order_delivery_on_3i"
    select "Tháng 1", from: "order_delivery_on_2i"
    select (Date.current.year + 1).to_s, from: "order_delivery_on_1i"
    select (Date.current.year + 1).to_s, from: "order_pickup_at_1i"
    select "Tháng 3", from: "order_pickup_at_2i"
    select "10", from: "order_pickup_at_3i"
    select "08", from: "order_pickup_at_4i"
    select "30", from: "order_pickup_at_5i"
    if slot
      select "09", from: "order_delivery_slot_4i"
      select "30", from: "order_delivery_slot_5i"
    end
    check "Gói quà"
    check "Bảo hiểm"
    fill_in "Mã SKU", with: "SKU1"
    fill_in "Số lượng", with: "2"
    fill_in "Đơn giá", with: "199.5"
  end

  # README: Types and strict coercion (date_select, datetime_select, time_select parts)
  it "creates the order through f.submit", covers: %w[date-select-parts datetime-select-parts time-select-parts date-parts-blank absent-blank-array-element] do
    visit new_order_path(locale: :vi)
    fill_form
    click_button "Tạo đơn", exact: true

    expect(page).to have_css("h1", text: /ORD-/)
    order = Order.last
    expect(page).to have_current_path(order_path(order), ignore_query: true)
    expect(order.customer.email).to eq("ben@example.com")
    expect(order.services).to eq(%w[gift_wrap insurance])
    expect(order.delivery_slot.strftime("%H:%M")).to eq("09:30")

    within_frame("inspector-frame") do
      expect(page).to have_css("#inspector-status", text: "303")
      expect(page).to have_css("#inspector-raw-params", text: "(1i)")
      expect(page).to have_css("#inspector-raw-params", text: "services")
      expect(page).not_to have_css("#inspector-permitted", text: "Bị từ chối")
    end
  end

  it "creates the order through button_tag" do
    visit new_order_path(locale: :vi)
    fill_form
    click_button "Tạo đơn (nút)"

    expect(page).to have_css("h1", text: /ORD-/)
    expect(page).to have_current_path(order_path(Order.last), ignore_query: true)
    expect(Order.count).to eq(1)
  end

  it "re-renders the errors in place", covers: %w[date-parts-invalid date-parts-blank] do
    visit new_order_path(locale: :vi)
    fill_in "Email", with: "nope"
    select "30", from: "order_delivery_on_3i"
    select "Tháng 2", from: "order_delivery_on_2i"
    select (Date.current.year + 1).to_s, from: "order_delivery_on_1i"
    fill_in "Số lượng", with: "0"
    click_button "Tạo đơn", exact: true

    expect(page).to have_css(%(li[data-param="order.customer.email"]), text: "sai định dạng")
    expect(page).to have_current_path(orders_path, ignore_query: true)
    expect(page).to have_css("form")
    expect(page).to have_css(%(li[data-param="order.delivery_on"][data-code="invalid_type"]))
    expect(page).to have_css(%(li[data-param="order.items_attributes[0].quantity"][data-code="inclusion"]))
    within_frame("inspector-frame") do
      expect(page).to have_css("#inspector-status", text: "422")
      expect(page).to have_css("#inspector-permitted", text: "Bị từ chối")
    end
    expect(Order.count).to eq(0)

    # one date part left on its prompt
    select "15", from: "order_delivery_on_3i"
    select "Tháng 2", from: "order_delivery_on_2i"
    select (Date.current.year + 1).to_s, from: "order_delivery_on_1i"
    first_prompt = find("#order_delivery_on_3i").all("option").first.text
    select first_prompt, from: "order_delivery_on_3i"
    click_button "Tạo đơn", exact: true
    expect(page).to have_css(%(li[data-param="order.delivery_on"][data-code="missing"]))
    expect(Order.count).to eq(0)
  end

  it "switches the locale", covers: %w[i18n-per-request-locale] do
    visit new_order_path(locale: :vi)
    click_link "English"
    expect(page).to have_css("label", text: "Name")
    expect(page).to have_css("h1", text: "Create order")

    click_button "Create order", exact: true
    expect(page).to have_css(%(li[data-param="order.customer.name"]), text: "is required")
  end

  it "reads an untouched time_select as 00:00", covers: %w[time-select-parts] do
    visit new_order_path(locale: :vi)
    fill_form(slot: false)
    click_button "Tạo đơn", exact: true

    expect(page).to have_css("h1", text: /ORD-/)
    expect(Order.last.delivery_slot.strftime("%H:%M")).to eq("00:00")
  end
end
