require "spec_helper"

RSpec.describe Customer do
  it "is valid with name and email" do
    expect(Customer.new(name: "An", email: "an@example.com")).to be_valid
  end

  it "requires name and email" do
    customer = Customer.new
    expect(customer).not_to be_valid
    expect(customer.errors.attribute_names).to include(:name, :email)
  end
end
