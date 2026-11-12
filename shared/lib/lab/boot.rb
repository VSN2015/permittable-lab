require "pathname"

module Lab
  # Called from each app's config/application.rb. Registers root/shared with the
  # app so the shared code is loaded exactly like the app's own code.
  module Boot
    module_function

    def configure(config, root:)
      shared = Pathname.new(root).join("shared")

      Dir[shared.join("app/*").to_s].sort.each do |dir|
        next unless File.directory?(dir)
        next if File.basename(dir) == "views" # templates, not Ruby constants
        config.autoload_paths << dir
        config.eager_load_paths << dir
      end

      # Concerns dirs are roots too: app/models/concerns/x.rb defines X, not Models::Concerns::X.
      Dir[shared.join("app/*/concerns").to_s].sort.each do |dir|
        next if File.basename(File.dirname(dir)) == "views"
        config.autoload_paths << dir
        config.eager_load_paths << dir
      end

      # Constants that initializers use (the Inspector middleware) must load
      # before the main autoloader is set up, and are never reloaded.
      config.autoload_once_paths << shared.join("app/inspector").to_s

      paths = config.paths
      paths["app/views"] << shared.join("app/views").to_s
      paths["app/helpers"] << shared.join("app/helpers").to_s
      paths["config/locales"] << shared.join("config/locales").to_s
      paths["config/initializers"] << shared.join("config/initializers").to_s
      paths["config/routes.rb"] << shared.join("config/routes.rb").to_s
      paths["db/migrate"] << shared.join("db/migrate").to_s
      paths["db/seeds.rb"].unshift(shared.join("db/seeds.rb").to_s)

      config.i18n.available_locales = %i[vi en]
      config.i18n.default_locale = :vi
      config.active_record.dump_schema_after_migration = false
    end
  end
end
