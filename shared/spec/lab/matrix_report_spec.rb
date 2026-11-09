# README: Development
require "lab/matrix_report"
RSpec.describe Lab::MatrixReport do
  def report(overrides = {})
    {
      "rails_version" => "8.1.4.1", "ruby_version" => "3.3.13",
      "gem" => { "source" => "local", "requested_version" => nil, "version" => "0.13.1" },
      "examples" => 5, "green" => 5, "failures" => 0, "pending" => 0,
      "errors_outside_examples" => 0, "failed" => [], "not_applicable" => []
    }.merge(overrides)
  end

  def row(rep, exit_status = 0, version: "8.1")
    Lab::MatrixReport.row(version: version, report: rep, exit_status: exit_status)
  end

  it("passes when all green and exit 0") { expect(row(report).status).to eq :pass }

  it "is red with failures" do
    r = row(report("failures" => 1, "green" => 4, "failed" => [{ "location" => "./a_spec.rb:1", "description" => "x" }]), 1)
    expect(r.status).to eq :red
    expect(r.failed).to eq ["./a_spec.rb:1"]
  end

  it("is red with held examples") { expect(row(report("pending" => 1, "green" => 4)).status).to eq :red }
  it("is red with errors outside examples") { expect(row(report("errors_outside_examples" => 1), 1).status).to eq :red }
  it("is failed_to_run for a nil report") { expect(row(nil, 1).status).to eq :failed_to_run }
  it("is failed_to_run when nothing ran") { expect(row(report("examples" => 0, "green" => 0)).status).to eq :failed_to_run }
  it("is failed_to_run when exit status disagrees with the report") { expect(row(report, 1).status).to eq :failed_to_run }

  it "builds the gem label" do
    expect(row(report).gem_label).to eq "permittable 0.13.1 (local)"
    pinned = report("gem" => { "source" => "rubygems", "requested_version" => "0.12.0", "version" => "0.12.0" })
    expect(row(pinned).gem_label).to eq "permittable 0.12.0 (rubygems, pinned)"
  end

  it "renders not-applicable cases with since" do
    na = %w[a b c].map { |d| { "description" => "case #{d}", "location" => "./x_spec.rb:1", "since" => "0.13.0" } }
    rep = report("gem" => { "source" => "rubygems", "requested_version" => "0.12.0", "version" => "0.12.0" }, "not_applicable" => na)
    out = Lab::MatrixReport.render([row(rep)])
    expect(out).to include("Rails | Ruby | Gem | Green | Red | N/A | Result")
    expect(out).to include("3 cases not applicable to permittable 0.12.0")
    %w[a b c].each { |d| expect(out).to include("case #{d}") }
    expect(out).to include("since 0.13.0")
  end

  it "renders FAILED TO RUN for a nil report" do
    expect(Lab::MatrixReport.render([row(nil, 2, version: "7.2")])).to include("FAILED TO RUN")
  end

  it "explains each failed-to-run reason" do
    log = ->(rep, st) { Lab::MatrixReport.render([Lab::MatrixReport.row(version: "8.1", report: rep, exit_status: st, log_path: "tmp/x.log")]) }
    expect(log.(nil, 1)).to include("no report")
    expect(log.(report("examples" => 0, "green" => 0), 0)).to include("nothing ran (0 examples)")
    out = log.(report, 3)
    expect(out).to include("exit 3 disagrees with report")
    expect(out).not_to include("no report")
  end

  it "explains red rows caused by held examples or outside errors" do
    rep = report("pending" => 2, "errors_outside_examples" => 1, "green" => 3)
    out = Lab::MatrixReport.render([Lab::MatrixReport.row(version: "8.1", report: rep, exit_status: 1, log_path: "tmp/x.log")])
    expect(out).to include("pending: 2")
    expect(out).to include("errors outside examples: 1")
    expect(out).to include("log: tmp/x.log")
  end

  it "computes the exit code" do
    pass = row(report)
    expect(Lab::MatrixReport.exit_code([pass, pass])).to eq 0
    expect(Lab::MatrixReport.exit_code([pass, row(nil, 1)])).to eq 1
  end
end
