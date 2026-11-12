# README: Standalone contracts (no controller)
RSpec.describe StatusChange, covers: %w[] do
  def violations(hash)
    StatusChange.call(hash).violations.map { |v| [v[:param], v[:code].to_s] }
  end

  it "fills remind_after with its default as authored" do
    result = StatusChange.call({ "status" => "shipped" })
    expect(result.params).to eq({ "status" => "shipped", "remind_after" => 1800 })
  end

  it "transforms remind_after minutes into seconds" do
    expect(StatusChange.call({ "status" => "shipped", "remind_after" => "45" }).params["remind_after"]).to eq 2700
  end

  it "rejects an unknown status" do
    expect(violations({ "status" => "lost" })).to eq [%w[status inclusion]]
  end

  it "reads in: Hash as its keys, refusing the stored integer" do
    expect(violations({ "status" => "cancelled", "cancel_reason" => "wrong_address" })).to eq []
    expect(violations({ "status" => "cancelled", "cancel_reason" => "1" })).to eq [%w[cancel_reason inclusion]]
  end

  it "rejects remind_after over four digits" do
    expect(violations({ "status" => "shipped", "remind_after" => "99999" })).to eq [%w[remind_after format]]
  end
end
