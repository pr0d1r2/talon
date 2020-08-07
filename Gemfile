source 'https://rubygems.org'
ruby '2.4.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 5.1.2'
gem 'pg'
gem 'hiredis'
gem 'redis', require:  ["redis", "redis/connection/hiredis"]
gem 'redis-rails', '~> 5.0.0'

gem 'sass-rails'
gem 'uglifier'
gem 'webpacker'
# gem 'font-awesome-rails'

gem 'sidekiq'
gem 'httparty'
gem 'm3u8'
gem 'rack-mini-profiler', require: false
gem 'streamio-ffmpeg'
gem 'message_bus'
gem 'paperclip'
gem 'fog-google'
gem 'fog-local'
gem 'active_model_serializers'
gem 'sentry-raven'
gem 'rufus-scheduler'
gem 'fast_xor'

group :development, :test do
  gem 'byebug', platform: :mri
  gem 'rspec-rails'
  gem 'bundle-audit'
end

group :test do
  gem 'timecop'
  gem 'mocha'
  gem 'database_cleaner'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers', '~> 4.0'
  gem 'rspec_junit_formatter'
  gem 'fabrication'
  gem 'selenium-webdriver'
  gem 'webdrivers', require: false
  gem 'capybara'
end

group :development do
  gem 'web-console'
  gem 'listen'
  gem 'spring'
  gem 'spring-watcher-listen'
end

gem 'puma', require: false
