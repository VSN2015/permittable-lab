# README: Compatibility
require "lab/boot"
require "ostruct"
require "tmpdir"
require "fileutils"

RSpec.describe Lab::Boot, covers: %w[] do
  def build_cfg
    OpenStruct.new(autoload_paths: [], eager_load_paths: [], autoload_once_paths: [],
                   paths: Hash.new { |h, k| h[k] = [] }, i18n: OpenStruct.new, active_record: OpenStruct.new)
  end

  def configure(*dirs)
    Dir.mktmpdir do |root|
      dirs.each { |d| FileUtils.mkdir_p(File.join(root, "shared/app", d)) }
      cfg = build_cfg
      Lab::Boot.configure(cfg, root: root)
      yield cfg, root
    end
  end

  it "registers app/*/concerns as roots beside their parent" do
    configure("controllers/concerns", "models/concerns", "views/orders", "inspector") do |cfg, root|
      %w[controllers/concerns models/concerns controllers models].each do |d|
        path = "#{root}/shared/app/#{d}"
        expect(cfg.autoload_paths).to include(path)
        expect(cfg.eager_load_paths).to include(path)
      end
    end
  end

  it "registers no concerns root that does not exist" do
    configure("controllers") do |cfg, _root|
      expect((cfg.autoload_paths + cfg.eager_load_paths).grep(%r{/concerns\z})).to eq []
    end
  end

  it "keeps views out of the autoload paths" do
    configure("views/concerns", "controllers") do |cfg, _root|
      expect((cfg.autoload_paths + cfg.eager_load_paths).grep(%r{/views\z})).to eq []
      expect((cfg.autoload_paths + cfg.eager_load_paths).grep(%r{/views/})).to eq []
    end
  end
end
