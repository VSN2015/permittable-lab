RSpec.describe Lab::Since do
  local = Lab::GemSource.from_env({})
  pinned = ->(v) { Lab::GemSource.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => v) }

  it("never excludes with the local gem") { expect(Lab::Since.applies?("9.9.9", source: local, gem_version: "0.1.0")).to be true }
  it("excludes when the pinned version is older") { expect(Lab::Since.applies?("0.13.0", source: pinned.("0.12.0"), gem_version: "0.12.0")).to be false }
  it("includes at exactly the tagged version") { expect(Lab::Since.applies?("0.12.0", source: pinned.("0.12.0"), gem_version: "0.12.0")).to be true }
  it("compares numerically, not as strings") { expect(Lab::Since.applies?("0.13.0", source: pinned.("0.9.0"), gem_version: "0.9.0")).to be false }
  it("treats an untagged spec as applicable") { expect(Lab::Since.applies?(nil, source: pinned.("0.1.0"), gem_version: "0.1.0")).to be true }
  it("raises on a malformed tag") { expect { Lab::Since.applies?("soon", source: local, gem_version: "0.13.1") }.to raise_error(ArgumentError) }
end
