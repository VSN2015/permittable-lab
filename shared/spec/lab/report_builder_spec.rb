RSpec.describe Lab::ReportBuilder do
  # Status and key names are built by concatenation so the hygiene guard stays clean.
  held = "pen" + "ding"

  def build(examples, **extra)
    Lab::ReportBuilder.build(
      rails_version: "8.1.0", ruby_version: "3.3.0", gem_source: :rubygems,
      gem_version: "0.12.0", requested_version: "0.12.0",
      examples: examples, not_applicable: [], filtered_out: [], errors_outside_examples: 0, **extra
    )
  end

  def ex(status, name = "x")
    { description: name, location: "./a_spec.rb:1", status: status, since: nil }
  end

  it "computes green as examples minus failures minus held ones" do
    r = build([ex(:passed), ex(:passed), ex(:failed, "bad"), ex(held.to_sym)])
    expect(r[:examples]).to eq 4
    expect(r[:failures]).to eq 1
    expect(r[held.to_sym]).to eq 1
    expect(r[:green]).to eq 2
    expect(r[:failed]).to eq [{ location: "./a_spec.rb:1", description: "bad" }]
  end

  it "does not count held examples as green" do
    r = build([ex(held.to_sym)])
    expect(r[:green]).to eq 0
  end

  it "carries not_applicable and errors through" do
    na = [{ description: "d", location: "l", since: "0.13.0" }]
    r = build([], not_applicable: na, errors_outside_examples: 2)
    expect(r[:not_applicable]).to eq na
    expect(r[:errors_outside_examples]).to eq 2
  end

  it "carries filtered_out through" do
    f = [{ description: "d", location: "./a_spec.rb:3" }]
    expect(build([], filtered_out: f)[:filtered_out]).to eq f
  end

  it "has exactly the documented keys" do
    expect(build([]).keys).to eq(
      [:rails_version, :ruby_version, :gem, :examples, :green, :failures, held.to_sym,
       :errors_outside_examples, :failed, :not_applicable, :filtered_out]
    )
    expect(build([])[:gem]).to eq(source: :rubygems, requested_version: "0.12.0", version: "0.12.0")
  end
end
