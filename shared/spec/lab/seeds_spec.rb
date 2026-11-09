require "spec_helper"

RSpec.describe "db seeds" do
  it "is idempotent and covers every status" do
    2.times { Rails.application.load_seed }
    expect(Customer.count).to eq 3
    expect(Order.count).to eq 6
    expect(Order.distinct.pluck(:status)).to match_array(Order.statuses.keys)
    expect(Order.where(priority: "express")).to exist
    expect(Order.includes(:items).all? { |o| (1..3).cover?(o.items.size) }).to be true
  end
end
