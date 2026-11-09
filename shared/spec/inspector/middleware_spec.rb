require "rack/mock"

RSpec.describe Inspector::Middleware do
  let(:closable_body) do
    Class.new do
      attr_reader :closed
      def initialize(chunks) = @chunks = chunks
      def each(&block) = @chunks.each(&block)
      def close = @closed = true
    end
  end

  before { Inspector::Store.clear }
  after { Inspector::Store.clear }

  def run(app, path = "/x", drain: true, **opts)
    status, headers, body = described_class.new(app).call(Rack::MockRequest.env_for(path, opts))
    chunks = []
    body.each { |c| chunks << c } if drain
    [status, headers, chunks, body]
  end

  it "returns the same status, headers and body" do
    headers = { "content-type" => "text/plain", "x-one" => "1" }
    status, out_headers, chunks, = run(->(_env) { [200, headers.dup, ["abc"]] })
    expect(status).to eq 200
    expect(out_headers).to eq headers
    expect(chunks.join).to eq "abc"
  end

  it "closes the original body" do
    body = closable_body.new(["abc"])
    _, _, _, returned = run(->(_env) { [200, { "content-type" => "text/plain" }, body] })
    returned.close
    expect(body.closed).to be true
  end

  it "re-raises an exception from the app" do
    app = ->(_env) { raise KeyError, "boom" }
    expect { run(app) }.to raise_error(KeyError, "boom")
  end

  it "passes the response through when the query is not valid UTF-8" do
    status, = run(->(_env) { [418, { "content-type" => "text/plain" }, ["tea"]] }, "/x?a=%FF")
    expect(status).to eq 418
    entry = Inspector::Store.recent(1).first
    expect(entry.raw_params.first.first).to eq "(unparseable)"
  end

  it "does not record paths under /inspector" do
    run(->(_env) { [200, {}, ["ok"]] }, "/inspector/last")
    expect(Inspector::Store.recent(5)).to be_empty
  end

  it "rewinds rack.input after reading it" do
    seen = nil
    app = ->(env) { seen = env["rack.input"].read; [200, {}, ["ok"]] }
    run(app, "/x", method: "POST", params: "a=1&b=2")
    expect(seen).to eq "a=1&b=2"
    expect(Inspector::Store.recent(1).first.raw_params).to eq [%w[a 1], %w[b 2]]
  end

  it "records a body that is not urlencoded as (body)" do
    run(->(_env) { [200, {}, ["ok"]] }, "/x", method: "POST", input: '{"a":1}', "CONTENT_TYPE" => "application/json")
    expect(Inspector::Store.recent(1).first.raw_params).to eq [["(body)", '{"a":1}']]
  end

  it "does not buffer text/event-stream bodies" do
    body = Object.new
    def body.each = raise("must not be iterated")
    _, _, _, returned = run(->(_env) { [200, { "content-type" => "text/event-stream" }, body] }, "/x", drain: false)
    expect(returned).to equal body
  end
end
