require 'activesupport'
require File.join(File.dirname(__FILE__), 'blueprints/buildable')
require File.join(File.dirname(__FILE__), 'blueprints/namespace')
require File.join(File.dirname(__FILE__), 'blueprints/root_namespace')
require File.join(File.dirname(__FILE__), 'blueprints/plan')
require File.join(File.dirname(__FILE__), 'blueprints/file_context')
require File.join(File.dirname(__FILE__), 'blueprints/helper')
require File.join(File.dirname(__FILE__), 'blueprints/errors')
require File.join(File.dirname(__FILE__), 'blueprints/database_backends/abstract')
require File.join(File.dirname(__FILE__), 'blueprints/database_backends/active_record')
require File.join(File.dirname(__FILE__), 'blueprints/database_backends/none')
if defined? Spec or $0 =~ /script.spec$/
  require File.join(File.dirname(__FILE__), 'blueprints/rspec_extensions')
else
  require File.join(File.dirname(__FILE__), 'blueprints/test_unit_extensions')
end

module Blueprints
  PLAN_FILES = [nil, "spec", "test"].map do |dir|
    ["blueprint"].map do |file|
      path = File.join([dir, file].compact)
      ["#{path}.rb", File.join(path, "*.rb")]
    end
  end.flatten
  SUPPORTED_ORMS = [:none, :active_record]

  def self.framework_root
    @@framework_root ||= RAILS_ROOT rescue Rails.root rescue Merb.root rescue nil
  end

  def self.setup(current_context)
    Namespace.root.setup
    Namespace.root.copy_ivars(current_context)
    @@orm.start_transaction
  end

  def self.teardown
    @@orm.rollback_transaction
  end

  def self.load(options = {})
    options.assert_valid_keys(:delete_policy, :filename, :prebuild, :root, :orm)
    options.symbolize_keys!
    return unless Namespace.root.empty?

    orm = (options.delete(:orm) || :active_record).to_sym
    raise ArgumentError, "Unsupported ORM #{orm}. Blueprints supports only #{SUPPORTED_ORMS.join(', ')}" unless SUPPORTED_ORMS.include?(orm)
    @@orm = DatabaseBackends.const_get(orm.to_s.classify).new
    @@orm.delete_tables(@@delete_policy = options[:delete_policy])

    @@framework_root = options[:root] if options[:root]
    load_scenarios_files(options[:filename] || PLAN_FILES)

    Namespace.root.prebuild(options[:prebuild])
  end

  def self.load_scenarios_files(*patterns)
    patterns.flatten!
    patterns.collect! {|pattern| File.join(framework_root, pattern)} if framework_root

    patterns.each do |pattern|
      unless (files = Dir.glob(pattern)).empty?
        files.each{|f| FileContext.module_eval File.read(f)}
        return
      end
    end

    raise "Plans file not found! Put plans in #{patterns.join(' or ')} or pass custom filename pattern with :filename option"
  end

  def self.delete_tables(*tables)
    @@orm.delete_tables(@@delete_policy, *tables)
  end
end
