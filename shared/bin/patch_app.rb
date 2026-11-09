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
RSPEC
