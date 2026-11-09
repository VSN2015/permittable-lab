RSpec.describe Inspector::ControllerObserver do
  let(:error) { Permittable::InvalidParameters.new("bad", details: [{ param: "a", code: "format" }]) }

  def host(to_raise = nil, returns: nil)
    Class.new do
      define_method(:permitted_params) { |*| to_raise ? raise(to_raise) : returns }
      prepend Inspector::ControllerObserver
    end.new
  end

  after { Inspector::Current.entry = nil }

  it "re-raises the same InvalidParameters object when its bookkeeping fails" do
    entry = Inspector::Entry.new(violations: [], events: [], log_lines: [])
    allow(entry).to receive(:rejected=).and_raise("bookkeeping broke")
    Inspector::Current.entry = entry
    raised = nil
    begin
      host(error).permitted_params
    rescue Permittable::InvalidParameters => e
      raised = e
    end
    expect(raised).to equal(error)
  end

  it "returns the result when the success bookkeeping fails" do
    entry = Inspector::Entry.new
    allow(entry).to receive(:permitted=).and_raise("bookkeeping broke")
    Inspector::Current.entry = entry
    result = { "a" => 1 }
    expect(host(returns: result).permitted_params).to equal(result)
  end

  it "records a rejection on the current entry" do
    entry = Inspector::Entry.new(violations: [])
    Inspector::Current.entry = entry
    expect { host(error).permitted_params }.to raise_error(error)
    expect(entry.rejected).to be true
    expect(entry.violations).to eq [{ param: "a", code: "format", message: nil }]
  end
end
