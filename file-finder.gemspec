require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'file-finder'
  spec.version    = '0.5.0'
  spec.authors    = ['Daniel Berger', 'Rick Ohnemus']
  spec.license    = 'Apache-2.0'
  spec.summary    = 'A better way to find files (derived from file-find)'
  spec.email      = 'rick_ohnemus@gacm.org'
  spec.homepage   = 'http://github.com/joast/file-finder'
  spec.test_file  = 'test/test_file_finder.rb'
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']

  if $0 =~ /gem\z/
    spec.signing_key = File.expand_path("~/.ssh/gem-private_key.pem")
  end

  spec.extra_rdoc_files = ['README', 'CHANGES', 'MANIFEST']
  spec.required_ruby_version = '>= 1.9.3'

  spec.metadata = {
    'homepage_uri'      => 'https://github.com/joast/file-finder',
    'bug_tracker_uri'   => 'https://github.com/joast/file-finder/issues',
    'changelog_uri'     => 'https://github.com/joast/file-finder/blob/master/CHANGES',
    'documentation_uri' => 'https://github.com/joast/file-finder/wiki',
    'source_code_uri'   => 'https://github.com/joast/file-finder',
    'wiki_uri'          => 'https://github.com/joast/file-finder/wiki'
  }

  spec.add_dependency('sys-admin', '>= 1.6.0')
  spec.add_development_dependency('test-unit')
  spec.add_development_dependency('rake')

  spec.description = <<-EOF
    The file-finder library provides a better, more object oriented approach
    to finding files. It allows you to find files based on a variety of
    properties, such as access time, size, owner, etc. You can also limit
    directory depth.

    This is derived from file-find (https://github.com/djberg96/file-find).
    See the README file for the differences between file-find and file-finder.

    Please, don't blame Daniel for any bugs in this.
  EOF
end
