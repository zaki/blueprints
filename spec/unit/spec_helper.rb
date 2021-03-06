Root = Pathname.new(__FILE__).dirname.join('..', '..')
$: << Root.join('lib').to_s

require 'rspec'
require 'blueprints'
require File.dirname(__FILE__) + '/fixtures'

RSpec.configure do |config|
  config.mock_with :mocha

  config.after do
    Blueprints::Namespace.root.instance_variable_get(:@children).clear
    Blueprints::Namespace.root.executed_blueprints.clear
  end
end
