source 'https://rubygems.org'

gemspec

if (local_file = Pathname('Gemfile.local')).exist?
  eval local_file.read, binding, __FILE__, __LINE__
end
