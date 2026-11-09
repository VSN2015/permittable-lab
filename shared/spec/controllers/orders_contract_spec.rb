require "permittable/rspec"

# README: Testing contracts (RSpec matchers)
RSpec.describe OrdersController, since: "0.12.0",
  covers: %w[matcher-permit-param matcher-accept-reject matcher-negated matcher-preset absent-blank-array-only-result absent-default opt-nullable absent-nullable-normalize-blank] do
  def accepting(overrides = {})
    accept_params(OrderPayloads.form_params(overrides)).for_action(:create)
  end

  it "declares the create contract" do
    expect(described_class).to permit_param("customer.email").for_action(:create).as(:string).matching(:email).required
    expect(described_class).to permit_param("customer.phone").for_action(:create).sensitive
    expect(described_class).to permit_param(:delivery_on).for_action(:create).as(:date).required
    expect(described_class).to permit_param(:priority).for_action(:create).within(%w[standard express]).with_default("standard")
    expect(described_class).to permit_param(:note).for_action(:create).nullable.optional.with_length(1..200)
    expect(described_class).to permit_param(:services).for_action(:create).as_array(of: :string)
    expect(described_class).to permit_param("items_attributes.quantity").for_action(:create).as(:integer).within(1..99)
    expect(described_class).to permit_param("shipping_address.city").for_action(:create).as(:string).required
  end

  it "does not declare the server-owned columns" do
    %i[status code customer_id].each { |f| expect(described_class).not_to permit_param(f).for_action(:create) }
  end

  it "accepts the browser payload and returns the cast output" do
    expect(described_class).to accept_params(OrderPayloads.form_params).for_action(:create).returning(OrderPayloads.contract_output)
  end

  it "reads a scalar array holding only the hidden blank as an empty array" do
    expect(described_class).to accepting("services" => [""]).returning(OrderPayloads.contract_output.merge("services" => []))
  end

  it "reads whitespace in a nullable squished field as nil" do
    expect(described_class).to accepting("note" => "   ").returning(OrderPayloads.contract_output.merge("note" => nil))
  end

  it "reads an empty nullable field as nil" do
    expect(described_class).to accepting("note" => "").returning(OrderPayloads.contract_output.merge("note" => nil))
  end

  it "returning is an exact match, so an omitted note is not the same as a nil note" do
    out = OrderPayloads.contract_output
    expect(out).to have_key("note")
    expect do
      expect(described_class).to accept_params(OrderPayloads.form_params("note" => "   ")).for_action(:create)
        .returning(out.except("note"))
    end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end

  it "fills an absent priority with the default" do
    payload = OrderPayloads.form_params("priority" => nil)
    expect(payload["order"]).not_to have_key("priority")
    expect(described_class).to accept_params(payload).for_action(:create)
      .returning(OrderPayloads.contract_output.merge("priority" => "standard"))
  end

  it "rejects named violations" do
    expect(described_class).to reject_params(OrderPayloads.form_params("customer" => { "name" => "", "email" => "x" })).for_action(:create)
      .with_violation("order.customer.name", :missing).with_violation("order.customer.email", :format)
  end

  it "negated forms" do
    expect(described_class).not_to accept_params(order: {}).for_action(:create)
    expect(described_class).not_to reject_params(OrderPayloads.form_params).for_action(:create)
  end

  it "fails negated matchers when no rule covers the action" do
    fails = RSpec::Expectations::ExpectationNotMetError
    expect { expect(described_class).not_to permit_param(:status).for_action(:index) }.to raise_error(fails)
    expect { expect(described_class).not_to accept_params(OrderPayloads.form_params).for_action(:index) }.to raise_error(fails)
    expect { expect(described_class).not_to reject_params(OrderPayloads.form_params).for_action(:index) }.to raise_error(fails)
  end

  it "raises on a qualified negated permit_param" do
    expect { expect(described_class).not_to permit_param(:status).for_action(:create).required }.to raise_error(ArgumentError, /cannot take qualifiers/)
  end

  it "raises when returning is chained onto reject_params" do
    expect { reject_params(OrderPayloads.form_params).returning({}) }.to raise_error(ArgumentError, /belongs to accept_params/)
  end
end
