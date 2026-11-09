# README: Compatibility
RSpec.describe "shared code is loaded as the app's own code", covers: %w[] do
  %w[BaseController HomeController].each do |name|
    it "#{name} is defined by a real path inside Rails.root, not via a symlink" do
      Object.const_get(name) # trigger the autoload; before it, the location is Zeitwerk's registration
      path = Object.const_source_location(name).first
      expect(path).to start_with(Rails.root.join("shared").to_s + "/")
      expect(File.realpath(path)).to eq path
    end
  end

  it "registers shared dirs with the app" do
    cfg = Rails.application.config
    expect(cfg.paths["db/migrate"].expanded).to include(Rails.root.join("shared/db/migrate").to_s)
    expect(I18n.load_path.map(&:to_s)).to include(Rails.root.join("shared/config/locales/vi.yml").to_s)
    expect(ApplicationController.view_paths.map(&:to_s)).to include(Rails.root.join("shared/app/views").to_s)
  end

  it "eager loads without error" do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end
