# README: How a request flows; Unknown parameters; Output reshaping
RSpec.describe "Sửa đơn through the real forms (headless Chromium)", type: :system, since: "0.12.0",
               covers: %w[unknown-exempt-form-keys unknown-exempt-csrf unknown-exempt-commit unknown-exempt-button] do
  include OrderPayloads

  before do
    Inspector::Store.clear
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end
  after { ActionController::Base.allow_forgery_protection = @original_forgery_protection }

  def raw_row(name, value)
    %(//*[@id="inspector-raw-params"]//tr[td[1][normalize-space()="#{name}"] and td[2][normalize-space()="#{value}"]])
  end

  it "edits an order through the real form", covers: %w[absent-optional-omitted] do
    order = create_order(priority: "express", note: "keep", services: %w[gift_wrap])
    # not on the edit form, so the browser never sends them
    order.update!(pickup_at: Time.utc(2030, 3, 10, 8, 30), delivery_slot: Time.utc(1, 1, 1, 9, 30))
    pickup_at, delivery_slot = order.pickup_at, order.delivery_slot
    visit order_path(order, locale: :vi)
    click_link "Sửa đơn"

    expect(find_field("Ghi chú").value).to eq("keep")
    expect(page).to have_checked_field("Gói quà")

    fill_in "Ghi chú", with: "  giao   buổi sáng "
    uncheck "Gói quà"
    check "Bảo hiểm"
    click_button "Lưu thay đổi"

    expect(page).to have_css("h1", text: order.code)
    expect(page).to have_css("#flash-notice", text: /Đã cập nhật/)
    order.reload
    expect(order.note).to eq("giao buổi sáng")
    expect(order.services).to eq(%w[insurance])
    expect(order.priority).to eq("express")
    expect(order.pickup_at).to eq(pickup_at)
    expect(order.delivery_slot).to eq(delivery_slot)

    within_frame("inspector-frame") do
      expect(page).to have_css("#inspector-status p:first-of-type", text: /\APATCH \/orders\/#{order.id} → 303\z/)
      expect(page).to have_xpath(raw_row("_method", "patch"))
      expect(page).to have_xpath(raw_row("order[services][]", ""))
      expect(page).not_to have_css("#inspector-permitted", text: "Bị từ chối")
    end
  end

  it "shows a violation in place" do
    order = create_order
    visit edit_order_path(order, locale: :vi)
    fill_in "Mã giảm giá", with: "abc"
    click_button "Lưu thay đổi"

    expect(page).to have_css(%(li[data-param="order.coupon_code"][data-code="format"]))
    expect(page).to have_field("Mã giảm giá") # the view re-renders the stored order, not the input
    expect(page).to have_current_path(order_path(order), ignore_query: true)
    within_frame("inspector-frame") do
      expect(page).to have_css("#inspector-status p:first-of-type", text: /\APATCH \/orders\/#{order.id} → 422\z/)
      expect(page).to have_css("#inspector-permitted", text: "Bị từ chối")
    end
  end

  describe "the rootless status form" do
    let!(:order) { create_order }

    before { visit order_path(order, locale: :vi) }

    it "changes status through f.submit", covers: %w[msg-violate-keyword unknown-exempt-path-params finalize-violate] do
      select "Đã huỷ", from: "status"
      click_button "Cập nhật trạng thái", exact: true

      expect(page).to have_css(%(li[data-param="cancel_reason"][data-code="required_when_cancelled"]), text: "bắt buộc khi trạng thái là Đã huỷ")
      within_frame("inspector-frame") do
        expect(page).to have_css("#inspector-status p:first-of-type", text: /\APATCH \/orders\/#{order.id}\/status → 422\z/)
        expect(page).to have_css("#inspector-violations", text: "cancel_reason")
      end

      # the re-rendered show page resets the status select to the stored value
      select "Đã huỷ", from: "status"
      select "Sai địa chỉ", from: "cancel_reason"
      click_button "Cập nhật trạng thái", exact: true

      expect(page).to have_css("p", text: /\ATrạng thái: Đã huỷ\z/)
      expect(page).to have_css("#cancel-reason", text: "Lý do huỷ: Sai địa chỉ")
      expect(page).to have_css("#remind-after", text: "Nhắc khách sau: 1800 giây")
      within_frame("inspector-frame") do
        expect(page).to have_css("#inspector-status p:first-of-type", text: /\APATCH \/orders\/#{order.id}\/status → 303\z/)
        %w[_method commit authenticity_token].each do |key|
          expect(page).to have_xpath(%(//*[@id="inspector-raw-params"]//tr[td[1][normalize-space()="#{key}"]]))
        end
      end
    end

    it "changes status through button_tag" do
      select "Đã huỷ", from: "status"
      select "Sai địa chỉ", from: "cancel_reason"
      click_button "Cập nhật trạng thái (nút)"

      expect(page).to have_css("#cancel-reason", text: "Lý do huỷ: Sai địa chỉ")
      within_frame("inspector-frame") do
        expect(page).to have_css("#inspector-status p:first-of-type", text: /\APATCH \/orders\/#{order.id}\/status → 303\z/)
        expect(page).to have_xpath(raw_row("button", ""))
      end
    end

    it "converts a custom reminder from minutes to seconds" do
      fill_in "Nhắc khách sau (phút)", with: "45"
      select "Đang giao", from: "status"
      click_button "Cập nhật trạng thái", exact: true

      expect(page).to have_css("#remind-after", text: "2700 giây")
    end
  end
end
