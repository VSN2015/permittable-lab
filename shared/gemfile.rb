# Evaluated from each app's Gemfile via eval_gemfile (added by shared/bin/patch_app.rb).
require File.expand_path("lib/lab/gem_source", __dir__)

gem(*Lab::GemSource.from_env.gem_args)

group :development, :test do
  gem "rspec-rails"
  gem "capybara"
  gem "cuprite"
end
