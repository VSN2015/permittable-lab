RSpec.describe Lab::Hygiene do
  banned = [
    "sk" + "ip", "pen" + "ding", "x" + "it", "x" + "describe", "x" + "context", "x" + "specify",
    "f" + "it", "f" + "describe", "f" + "context", "foc" + "us: true", ":sk" + "ip", ":pen" + "ding",
    "RSpec::Core::" + "Pending", "filter_run_" + "excluding", "known_" + "bug"
  ]

  banned.each do |word|
    it "reports #{word.inspect} with the file name" do
      v = Lab::Hygiene.violations("  #{word} \"x\" do\n", "shared/spec/requests/a_spec.rb")
      expect(v.size).to be >= 1
      expect(v.first).to include("shared/spec/requests/a_spec.rb")
    end
  end

  it "allows the exclusion filter in spec_helper and lib/lab" do
    src = "config.filter_run_" + "excluding since: 1\n"
    expect(Lab::Hygiene.violations(src, "shared/spec/spec_helper.rb")).to eq []
    expect(Lab::Hygiene.violations(src, "shared/lib/lab/x.rb")).to eq []
  end

  it "ignores text after a comment marker and string contents" do
    expect(Lab::Hygiene.violations("a = 1 # " + "sk" + "ip this\n", "shared/spec/a_spec.rb")).to eq []
    expect(Lab::Hygiene.violations("it \"does not " + "sk" + "ip\" do\nend\n", "shared/spec/a_spec.rb")).to eq []
  end

  it "matches whole words only" do
    expect(Lab::Hygiene.violations("benefit = 1\nskipper = 2\n", "shared/spec/a_spec.rb")).to eq []
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
