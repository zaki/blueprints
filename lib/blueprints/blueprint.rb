module Blueprints
  # Class for actual blueprints. Allows building itself by executing block passed against current context.
  class Blueprint < Buildable
    # Holds how many times this particular blueprint was built
    attr_reader :uses

    # Initializes blueprint by name, context and block. Also sets default demolish and update blocks.
    # @param name (see Buildable#initialize)
    # @param context (see Buildable#initialize)
    def initialize(name, context, &block)
      super(name, context)

      @strategies = {}
      @strategies[:default] = block
      @strategies[:demolish] = Proc.new { instance_variable_get(variable_name).destroy }
      @strategies[:update] = Proc.new { instance_variable_get(variable_name).blueprint(options) }
      @uses = 0
    end

    # Changes blueprint block to build another blueprint by passing additional options to it. Usually used to dry up
    # blueprints that are often built with some options.
    # @example Extending blueprints
    #   Post.blueprint :post, :title => 'hello blueprints'
    #   blueprint(:published_post).extends(:post, :published_at => Time.now)
    # @param [Symbol, String] parent Name of parent blueprint.
    # @param [Hash] options Options to be passed when building parent.
    def extends(parent, options = {})
      attributes(options).blueprint(:default) { build parent => attributes }
    end

    # @overload demolish(&block)
    #   Sets custom block for demolishing this blueprint.
    # @overload demolish(environment)
    #   Demolishes blueprint by calling demolish block.
    #   @param [Object] environment Context where blueprint was built in.
    #   @param [Symbol] current_name Current name of blueprint (used when demolishing blueprints with regexp name). When nil is passed then @name is used.
    #   @raise [Blueprints::DemolishError] If blueprint has not been built yet.
    def demolish(environment = nil, current_name = nil, &block)
      if block
        blueprint(:demolish, &block)
      elsif environment and built?
        eval_block(environment, {}, current_name, &@strategies[:demolish])
        undo!
      else
        raise DemolishError, @name
      end
    end

    # Allows customizing what happens when blueprint is already built and it's being built again.
    def update(&block)
      blueprint(:update, &block)
    end

    # Defines strategy for this blueprint. Blueprint can later be built using this strategy by passing :strategy option
    # to Buildable#build method.
    # @param [#to_sym] name Name of strategy.
    # @return [Blueprints::Blueprint] self.
    def blueprint(name, &block)
      @strategies[name.to_sym] = block
      self
    end

    # Returns normalized attributes for this blueprint. Normalized means that all dependencies are replaced by real
    # instances and all procs evaluated.
    # @param environment Context that blueprints are built against
    # @param [Hash] options Options hash, merged into attributes
    # @return [Hash] normalized attributes for this blueprint
    def normalized_attributes(environment, options = {})
      normalize_hash(environment, @context.attributes.merge(options))
    end

    private

    def build_self(environment, options)
      @uses += 1 unless built?
      opts = options[:options] || {}
      strategy = (options[:strategy] || :default).to_sym
      current_name = options[:name] || @name

      if built? and not options[:rebuild]
        eval_block(environment, opts, current_name, &@strategies[:update]) if opts.present?
      elsif @strategies[strategy]
        result(environment, current_name) { eval_block(environment, opts, current_name, &@strategies[strategy]) }
      end
    end

    def eval_block(environment, options, current_name, &block)
      with_method(environment, :options, options = normalize_hash(environment, options)) do
        with_method(environment, :attributes, normalized_attributes(environment, options)) do
          with_method(environment, :variable_name, variable_name(current_name)) do
            environment.instance_eval(&block)
          end
        end
      end
    end

    def normalize_hash(environment, hash)
      hash.each_with_object({}) do |(attr, value), normalized|
        normalized[attr] = if value.respond_to?(:to_proc) and not Symbol === value
                             environment.instance_exec(&value)
                           else
                             value
                           end
      end
    end

    def with_method(environment, name, value)
      old_method = nil
      environment.singleton_class.class_eval do
        if method_defined?(name)
          old_method = environment.method(name)
          remove_method(name)
        end
        define_method(name) { value }
      end
      yield
    ensure
      environment.singleton_class.class_eval do
        remove_method(name)
        define_method(name, old_method) if old_method
      end
    end
  end
end
