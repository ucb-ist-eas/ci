Gem::Specification.new do |s|
  s.name        = 'ucb_rails_ci'
  s.version     = '1.0.0'
  s.summary     = "CI and deployment integration for UCB Rails apps"
  s.description = "Tools for enabling Rails apps to be built on Travis and deployed from GitHub"
  s.authors     = ["Ken Miller"]
  s.email       = 'ken@berkeley.edu'
  s.date        = Time.now.utc.strftime("%Y-%m-%d")
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/ucb-ist-eas/ucb_rails_ci'
  s.bindir      = 'bin'

  s.add_runtime_dependency 'rake'
  s.add_runtime_dependency 'bundler'
  s.add_runtime_dependency 'builder'
  s.add_runtime_dependency 'warbler'
  s.add_runtime_dependency 'github_api'
  s.add_runtime_dependency 'travis'
end
