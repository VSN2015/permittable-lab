RSpec.describe Inspector::Store do
  def entry(id, method: "POST", permitted: nil)
    Inspector::Entry.new(request_id: id, method: method, path: "/x", permitted: permitted, raw_params: [], violations: [], events: [], log_lines: [])
  end

  before { described_class.clear }
  after { described_class.clear }

  it "keeps at most 50 entries and drops the oldest" do
    55.times { |i| described_class.record(entry("r#{i}")) }
    expect(described_class.recent(100).size).to eq 50
    expect(described_class.find("r0")).to be_nil
    expect(described_class.find("r4")).to be_nil
    expect(described_class.find("r5")).not_to be_nil
    expect(described_class.recent(1).first.request_id).to eq "r54"
  end

  it "latest skips an untracked GET and returns the earlier tracked POST" do
    described_class.record(entry("post-1"))
    described_class.record(entry("get-1", method: "GET"))
    expect(described_class.latest.request_id).to eq "post-1"
  end

  it "latest counts a GET that read permitted_params as tracked" do
    described_class.record(entry("post-1"))
    described_class.record(entry("get-1", method: "GET", permitted: { "a" => 1 }))
    expect(described_class.latest.request_id).to eq "get-1"
  end

  it "latest is nil when nothing is tracked" do
    described_class.record(entry("get-1", method: "GET"))
    expect(described_class.latest).to be_nil
  end

  it "finds an entry by request id" do
    described_class.record(entry("abc"))
    described_class.record(entry("def"))
    expect(described_class.find("abc").request_id).to eq "abc"
    expect(described_class.find("zzz")).to be_nil
  end

  it "loses nothing when 10 threads record concurrently, up to the cap" do
    10.times.map { |t| Thread.new { 4.times { |i| described_class.record(entry("t#{t}-#{i}")) } } }.each(&:join)
    expect(described_class.recent(100).size).to eq 40
    expect(described_class.recent(100).map(&:request_id).uniq.size).to eq 40
  end
end
