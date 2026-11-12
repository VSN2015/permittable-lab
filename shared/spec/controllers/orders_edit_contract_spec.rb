require "permittable/rspec"

# README: Testing contracts (RSpec matchers); Standalone contracts
RSpec.describe OrdersController, since: "0.12.0",
  covers: %w[matcher-accept-reject use-contract opt-in-enum-hash unknown-exempt-path-params cl-0_14_0-9] do
  it "declares the update contract" do
    expect(described_class).to permit_param(:priority).for_action(:update).within(%w[standard express]).optional
    expect(described_class).to permit_param(:delivery_on).for_action(:update).as(:date).optional
    expect(described_class).to permit_param(:note).for_action(:update).nullable
    expect(described_class).to permit_param("shipping_address.city").for_action(:update).required
    %i[status cancel_reason code customer].each do |guarded|
      expect(described_class).not_to permit_param(guarded).for_action(:update)
    end
  end

  it "does not fill defaults on update" do
    expect(described_class).to accept_params("order" => { "note" => "x" }).for_action(:update).returning("note" => "x")
  end

  it "declares the status contract through use StatusChange" do
    expect(described_class).to permit_param(:status).for_action(:change_status).as(:string).required.within(Order.statuses.keys)
    expect(described_class).to permit_param(:cancel_reason).for_action(:change_status).within(Order.cancel_reasons.keys).optional
    expect(described_class).not_to permit_param(:id).for_action(:change_status)
  end

  it "accepts and rejects status payloads" do
    expect(described_class).to accept_params("status" => "shipped").for_action(:change_status)
      .returning("status" => "shipped", "remind_after" => 1800)
    expect(described_class).to reject_params("status" => "cancelled").for_action(:change_status)
      .with_violation("cancel_reason", :required_when_cancelled)
    expect(described_class).to reject_params("status" => "cancelled", "cancel_reason" => "1").for_action(:change_status)
      .with_violation("cancel_reason", :inclusion)
  end

  # README "Testing contracts": leave path parameters out of the payload.
  it "matchers do not see path parameters" do
    expect(described_class).to reject_params("status" => "shipped", "id" => "1").for_action(:change_status)
      .with_violation("id", :unknown)
  end

  describe "deep munge", since: "0.14.0" do
    it "drops nil members of an array before the contract sees it" do
      expect(described_class).to accept_params("order" => { "services" => ["gift_wrap", nil] }).for_action(:update)
        .returning("services" => ["gift_wrap"])
      expect(described_class).not_to reject_params("order" => { "services" => [nil, "gift_wrap"] }).for_action(:update)
    end

    it "leaves a standalone contract unmunged" do
      contract = Permittable::Contract.define(root: :order) { array :services, of: :string }
      result = contract.call("order" => { "services" => ["gift_wrap", nil] })
      expect(result).not_to be_valid
      expect(result.violations.map { |v| [v[:param].to_s, v[:code].to_s] }).to include(["order.services[1]", "invalid_type"])
    end
  end

  describe "Symbol values", since: "0.15.0" do
    it "reads a Symbol as its String" do
      expect(described_class).to accept_params("status" => :shipped).for_action(:change_status)
        .returning("status" => "shipped", "remind_after" => 1800)
    end

    it "leaves a standalone contract strict" do
      result = StatusChange.call("status" => :shipped)
      expect(result).not_to be_valid
      expect(result.violations.map { |v| [v[:param].to_s, v[:code].to_s] }).to eq [["status", "invalid_type"]]
    end
  end

  describe "a blank default on a nullable field", since: "0.14.0" do
    # README: Explicit nulls (nullable:)
    def showing(&block)
      Class.new(BaseController) { permit_params(:show, &block) }
    end

    it "reads nil" do
      klass = showing { optional :note, :string, nullable: true, default: "" }
      expect(klass).to accept_params({}).for_action(:show).returning("note" => nil)
      expect(klass).to permit_param(:note).for_action(:show).with_default("")
    end

    it "reads nil after normalizing" do
      klass = showing { optional :note, :string, normalize: :strip, nullable: true, default: "   " }
      expect(klass).to accept_params({}).for_action(:show).returning("note" => nil)
    end

    it "loads and reads nil with in:, format: and an integer type" do
      {
        colour: showing { optional :colour, :string, in: %w[red], nullable: true, default: "" },
        code: showing { optional :code, :string, format: /\A\d+\z/, nullable: true, default: "" },
        age: showing { optional :age, :integer, nullable: true, default: "" }
      }.each do |name, klass|
        expect(klass).to accept_params({}).for_action(:show).returning(name.to_s => nil)
      end
    end

    it "keeps a non-nullable blank default as authored" do
      klass = showing { optional :note, :string, default: "" }
      expect(klass).to accept_params({}).for_action(:show).returning("note" => "")
    end

    it "keeps the default as authored when transform: is present" do
      klass = showing { optional :note, :string, nullable: true, transform: ->(v) { v.upcase }, default: "" }
      expect(klass).to accept_params({}).for_action(:show).returning("note" => "")
    end
  end
end
