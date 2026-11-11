require "open3"

RSpec.describe "Inspector in production" do
  it "is enabled only in development and test" do
    expect(Inspector.enabled?("production")).to be false
    expect(Inspector.enabled?("development")).to be true
    expect(Inspector.enabled?("test")).to be true
  end

  it "has both probes non-empty in the test process (positive control)" do
    expect(Rails.application.middleware.map(&:inspect).grep(/Inspector/)).not_to be_empty
    expect(Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(/inspector/)).not_to be_empty
  end

  it "installs no middleware and no routes when booted in production" do
    script = 'puts Rails.application.middleware.map(&:inspect).grep(/Inspector/).empty?; ' \
             'puts Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(/inspector/).empty?'
    env = { "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_ENV" => "production" }
    out, err, status = Open3.capture3(env, "bin/rails", "runner", script, chdir: Rails.root.to_s)
    expect(status.success?).to be(true), "boot failed: #{err}"
    expect(out.split("\n").last(2)).to eq %w[true true]
  end
end
