# README: Compatibility
RSpec.describe Lab::GemSource do
  it "defaults to local" do
    s = described_class.from_env({})
    expect([s.source, s.requested_version, s.gem_args]).to eq [:local, nil, ["permittable", { path: "/permittable" }]]
  end
  it "treats an empty PERMITTABLE_VERSION as unset" do   # Compose passes "" when unset
    expect(described_class.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "").gem_args).to eq ["permittable"]
  end
  it "pins an exact RubyGems version" do
    s = described_class.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "0.12.0")
    expect(s.gem_args).to eq ["permittable", "= 0.12.0"]
    expect(s.label("0.12.0")).to eq "permittable 0.12.0 (rubygems, pinned)"
    expect(s.lock_key).to eq "rubygems@0.12.0"
  end
  it "labels the local and unpinned cases" do
    expect(described_class.from_env({}).label("0.13.1")).to eq "permittable 0.13.1 (local)"
    expect(described_class.from_env("PERMITTABLE_SOURCE" => "rubygems").label("0.13.1")).to eq "permittable 0.13.1 (rubygems, latest)"
  end
  it "rejects a typo in the source" do
    expect { described_class.from_env("PERMITTABLE_SOURCE" => "rubygem") }.to raise_error(ArgumentError, /local, rubygems/)
  end
  it "rejects a version with the local source" do
    expect { described_class.from_env("PERMITTABLE_VERSION" => "0.12.0") }.to raise_error(ArgumentError, /only applies/)
  end
  it "rejects a non-version and a range" do
    %w[latest ~>0.12 >=0.1].each do |v|
      expect { described_class.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => v) }.to raise_error(ArgumentError)
    end
  end
end
