# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'exception_notification/version'

Gem::Specification.new do |s|
  s.name        = 'exception_notification'
  s.version     = ExceptionNotification::VERSION
  s.authors     = ['Richard Huang', 'Damian Janowski', 'David Youssef']
  s.email       = ['richardhuang@me.com', 'damian.janowski@gmail.com', 'david@davidyoussef.com']
  s.homepage    = 'https://smartinez87.github.io/exception_notification/'
  s.summary     = 'The best way to send notifications when errors occur in your Rack/Rails application.'
  s.description = 'Exception Notification is a gem that provides a set of notifiers for sending notifications when errors occur in a Rack/Rails application. Some of the supported notifiers are: :email, :campfire, :webhook, :slack, :hipchat, :flowdock, :freckle, :webhook, :rocketchat, :microsoft_teams, :mail, :post and :telegram.'

  s.files         = Dir['{app,config,lib}/**/*', 'CHANGELOG.md', 'MIT-LICENSE', 'README.md', 'init.rb']
  s.test_files    = Dir['{spec}/**/*']
  s.require_paths = ['lib']
  s.license       = 'MIT'

  s.required_ruby_version = '>= 2.6.0'

  s.add_dependency 'actionmailer', '>= 6.0.0'
  s.add_dependency 'activesupport', '>= 6.0.0'
  s.add_dependency 'rack', '>= 2.0.0'
  s.add_dependency 'railties', '>= 6.0.0'

  s.add_development_dependency 'appraisal', '~> 2.2'
  s.add_development_dependency 'aruba', '~> 1.0'
  s.add_development_dependency 'capybara', '~> 3.0'
  s.add_development_dependency 'coveralls', '~> 0.8'
  s.add_development_dependency 'cucumber', '~> 2.1'
  s.add_development_dependency 'delayed_job', '~> 4.1'
  s.add_development_dependency 'httparty', '~> 0.13'
  s.add_development_dependency 'pry', '~> 0.10'
  s.add_development_dependency 'rack-test', '~> 1.1'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'resque', '~> 1.25'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'sidekiq', '~> 5.0'
  s.add_development_dependency 'sqlite3', '~> 1.3'
  s.add_development_dependency 'thor', '~> 0.19'
  s.add_development_dependency 'timecop', '~> 0.8'
  s.add_development_dependency 'webmock', '~> 3.0'
end
