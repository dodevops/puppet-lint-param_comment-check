Gem::Specification.new do |spec|
  spec.name        = 'puppet-lint-param_comment-check'
  spec.version     = '0.1.1'
  spec.homepage    = 'https://github.com/dodevops/puppet-lint-param_comment-check'
  spec.license     = 'MIT'
  spec.author      = 'Dennis Ploeger'
  spec.email       = 'develop@dieploegers.de'
  spec.files       = Dir[
    'README.md',
    'LICENSE',
    'lib/**/*',
    'spec/**/*',
  ]
  spec.test_files  = Dir['spec/**/*']
  spec.summary     = 'A puppet-lint plugin to check @param comments'
  spec.description = <<-DESC
    A puppet-lint plugin to check that manifest files contain properly formatted @param comments.
  DESC

  spec.add_dependency             'finite_machine'
  spec.add_dependency             'puppet-lint', '> 1.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-collection_matchers', '~> 1.0'
  spec.add_development_dependency 'rspec-its', '~> 1.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
end
