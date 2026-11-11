RSpec.describe Lab::Hygiene do
  # [text, expected label]; banned words are built by concatenation.
  banned = [
    ["sk" + "ip", "skip"], ["pen" + "ding", "pending"], ["x" + "it", "xit"], ["x" + "describe", "xdescribe"],
    ["x" + "context", "xcontext"], ["x" + "specify", "xspecify"], ["x" + "example", "xexample"],
    ["f" + "it", "fit"], ["f" + "describe", "fdescribe"], ["f" + "context", "fcontext"],
    ["f" + "specify", "fspecify"], ["f" + "example", "fexample"],
    ["foc" + "us \"x\" do", "focus"], [":foc" + "us", "focus"], ["foc" + "us: true", "focus: true"],
    [":sk" + "ip", "skip"], [":pen" + "ding", "pending"],
    ["\"sk" + "ip\": true", "skip"], ["\"pen" + "ding\":", "pending"], ["\"foc" + "us\":", "focus"],
    [":\"sk" + "ip\"", "skip"], [":\"pen" + "ding\"", "pending"], [":\"foc" + "us\"", "focus"],
    ["RSpec::Core::" + "Pending", "RSpec::Core::Pending"], ["known_" + "bug", "known_bug"],
    ["filter_run_" + "excluding", "filter_run_excluding"], ["filter_run_when_" + "matching", "filter_run_when_matching"],
    ["filter_run_" + "including", "filter_run_including"], ["filter_" + "run", "filter_run"],
    ["exclusion_" + "filter", "exclusion_filter"]
  ]

  banned.each do |word, label|
    it "reports #{word.inspect} as #{label.inspect} with the file name" do
      v = Lab::Hygiene.violations("  #{word} do\n", "shared/spec/requests/a_spec.rb")
      expect(v.size).to be >= 1
      expect(v.first).to include("shared/spec/requests/a_spec.rb")
      expect(v.join("\n")).to include("banned #{label.inspect}")
    end
  end

  it "allows the exclusion filter in spec_helper and lib/lab" do
    src = "config.filter_run_" + "excluding since: 1\n"
    expect(Lab::Hygiene.violations(src, "shared/spec/spec_helper.rb")).to eq []
    expect(Lab::Hygiene.violations(src, "shared/lib/lab/x.rb")).to eq []
    expect(Lab::Hygiene.violations(src, "shared/spec/requests/spec_helper.rb")).not_to be_empty
    expect(Lab::Hygiene.violations(src, "other/spec_helper.rb")).not_to be_empty
  end

  it "ignores text after a comment marker and string contents" do
    expect(Lab::Hygiene.violations("a = 1 # " + "sk" + "ip this\n", "shared/spec/a_spec.rb")).to eq []
    expect(Lab::Hygiene.violations("it \"does not " + "sk" + "ip\" do\nend\n", "shared/spec/a_spec.rb")).to eq []
  end

  it "matches whole words only" do
    expect(Lab::Hygiene.violations("benefit = 1\nskipper = 2\n", "shared/spec/a_spec.rb")).to eq []
  end

  it "bans if:/unless: example metadata in specs (built by concatenation)" do
    ["i" + "f: -> { true }", "unl" + "ess: ->(v) { v }", ":i" + "f => 1", ":unl" + "ess => 1"].each do |meta|
      src = "it \"x\", #{meta} do\nend\n"
      expect(Lab::Hygiene.violations(src, "shared/spec/requests/a_spec.rb")).not_to be_empty, meta
    end
    expect(Lab::Hygiene.violations("x = a ? b : c\nputs(\"i\" + \"f:\")\nnotify: 1\n", "shared/spec/requests/a_spec.rb")).to eq []
    expect(Lab::Hygiene.violations("module A; end # i" + "f: here\n", "shared/spec/requests/a_spec.rb")).to eq []
  end

  it "bans Rails version comparisons in specs except spec_helper and home_spec" do
    ["Rails." + "version", "Rails::" + "VERSION", "Rails." + "gem_version"].each do |w|
      src = "x = #{w} >= \"8\"\n"
      expect(Lab::Hygiene.violations(src, "shared/spec/requests/a_spec.rb")).not_to be_empty, w
      expect(Lab::Hygiene.violations(src, "shared/spec/lab/a_spec.rb")).not_to be_empty, w
      expect(Lab::Hygiene.violations(src, "shared/spec/spec_helper.rb")).to eq []
      expect(Lab::Hygiene.violations(src, "shared/spec/requests/home_spec.rb")).to eq []
      expect(Lab::Hygiene.violations(src, "shared/lib/lab/x.rb")).to eq []
    end
  end

  it "flags raw HTTP in system specs but not in request specs" do
    sample = "page.driver." + "post('/x')\n"
    expect(Lab::Hygiene.violations(sample, "shared/spec/system/a_spec.rb")).not_to be_empty
    expect(Lab::Hygiene.violations(sample, "shared/spec/requests/a_spec.rb")).to eq []
    %w[driver.submit requestSubmit .submit( XMLHttpRequest].each do |w|
      expect(Lab::Hygiene.violations("x #{w}\n", "shared/spec/system/a_spec.rb")).not_to be_empty
    end
    expect(Lab::Hygiene.violations("fet" + "ch(1)\n", "shared/spec/system/a_spec.rb")).not_to be_empty
  end

  it "the real spec tree is clean" do
    root = File.expand_path("..", __dir__) # shared/spec
    files = Dir[File.join(root, "**/*.rb")]
    expect(files).not_to be_empty
    all = files.flat_map { |f| Lab::Hygiene.violations(File.read(f), "shared/spec/" + f.sub(root + "/", "")) }
    expect(all).to eq []
  end
end
