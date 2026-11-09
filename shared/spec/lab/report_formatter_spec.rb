require "stringio"
require "tmpdir"

RSpec.describe Lab::ReportFormatter do
  it "lists cases tagged newer than the pinned gem and records them in the JSON" do
    source = Lab::GemSource.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "0.12.0")
    meta = ->(since) { { since: since } }
    ex = Struct.new(:full_description, :location, :metadata)
    world = [ex.new("old thing", "./a_spec.rb:1", meta.(nil)), ex.new("new thing", "./a_spec.rb:2", meta.("0.13.0"))]
    notification = Struct.new(:examples, :errors_outside_of_examples_count).new([], 0)
    out = StringIO.new

    Dir.mktmpdir do |dir|
      path = File.join(dir, "tmp", "lab-report.json")
      described_class.new(out).write_report(
        notification, source: source, gem_version: "0.12.0", world_examples: world, path: path
      )
      report = JSON.parse(File.read(path))
      expect(report["not_applicable"]).to eq [
        { "description" => "new thing", "location" => "./a_spec.rb:2", "since" => "0.13.0" }
      ]
      expect(report["examples"]).to eq 0
    end
    expect(out.string).to include("1 cases not applicable to permittable 0.12.0")
    expect(out.string).to include("./a_spec.rb:2")
  end
end
