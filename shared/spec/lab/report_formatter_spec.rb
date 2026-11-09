require "stringio"
require "tmpdir"

RSpec.describe Lab::ReportFormatter do
  it "lists cases tagged newer than the pinned gem and records them in the JSON" do
    source = Lab::GemSource.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "0.12.0")
    meta = ->(since) { { since: since } }
    ex = Struct.new(:id, :full_description, :location, :metadata)
    ran = ex.new("./a[1:1]", "old thing", "./a_spec.rb:1", meta.(nil))
    world = [ran, ex.new("./a[1:2]", "new thing", "./a_spec.rb:2", meta.("0.13.0"))]
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

  it "records declared examples that neither ran nor are not-applicable as filtered_out" do
    source = Lab::GemSource.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "0.12.0")
    ex = Struct.new(:id, :full_description, :location, :metadata) do
      def execution_result = Struct.new(:status).new(:passed)
    end
    ran = ex.new("./a[1:1]", "ran", "./a_spec.rb:1", { since: nil })
    dropped = ex.new("./a[1:2]", "dropped by a filter", "./a_spec.rb:2", { since: nil })
    newer = ex.new("./a[1:3]", "newer", "./a_spec.rb:3", { since: "0.13.0" })
    notification = Struct.new(:examples, :errors_outside_of_examples_count).new([ran], 0)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "lab-report.json")
      described_class.new(StringIO.new).write_report(
        notification, source: source, gem_version: "0.12.0", world_examples: [ran, dropped, newer], path: path
      )
      report = JSON.parse(File.read(path))
      expect(report["filtered_out"]).to eq [
        { "description" => "dropped by a filter", "location" => "./a_spec.rb:2" }
      ]
      expect(report["not_applicable"].map { |c| c["description"] }).to eq ["newer"]
    end
  end
end
