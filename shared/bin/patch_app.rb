#!/usr/bin/env ruby
# Idempotent. Usage: ruby shared/bin/patch_app.rb APP_DIR  (plain Ruby, runs on 2.7+)
app = ARGV[0] or abort("usage: patch_app.rb APP_DIR")
abort("no such directory: #{app}") unless File.directory?(app)

gemfile = File.join(app, "Gemfile")
abort("no Gemfile in #{app}") unless File.file?(gemfile)
line = 'eval_gemfile File.expand_path("shared/gemfile.rb", __dir__)'
content = File.read(gemfile)
unless content.include?(line)
  content << "\n" unless content.end_with?("\n")
  File.write(gemfile, content + "\n" + line + "\n")
end

File.write(File.join(app, ".rspec"), <<~RSPEC)
  --default-path shared/spec
  --require spec_helper
  --format progress
  --format Lab::ReportFormatter
RSPEC

# Hook shared/ into config/application.rb (Lab::Boot).
appcfg = File.join(app, "config", "application.rb")
if File.file?(appcfg)
  src = File.read(appcfg)
  req = 'require_relative "../shared/lib/lab/boot"'
  cfg = 'Lab::Boot.configure(config, root: Pathname.new(File.expand_path("..", __dir__)))'
  unless src.include?(req)
    src = src.sub(/^(Bundler\.require\(.*\)\n)/) { "#{$1}#{req}\n" } or abort("no Bundler.require in application.rb")
  end
  unless src.include?(cfg)
    src = src.sub(/^(\s*)(config\.load_defaults .*\n)/) { "#{$1}#{$2}#{$1}#{cfg}\n" }
    abort("no config.load_defaults in application.rb") unless src.include?(cfg)
  end
  File.write(appcfg, src)
end
