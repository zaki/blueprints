module Blueprints
  # Namespace class, inherits from <tt>Buildable</tt>. Allows adding and finding child blueprints/namespaces and building
  # all it's children.
  class Namespace < Buildable
    cattr_accessor :root
    attr_reader :children
    delegate :empty?, :size, :to => :@children

    # Creates namespace by name. See Buildable#new.
    def initialize(name)
      super(name)
      @children = {}
    end

    # Adds child to namespaces children. Child should be instance of Buildable.
    def add_child(child)
      @children[child.name] = child
      child.namespace = self
    end

    # Finds child by relative name. Raises PlanNotFoundError if child can't be found.
    def [](path)
      child_name, path = path.to_s.split('.', 2)
      child = @children[child_name.to_sym] or raise PlanNotFoundError, child_name
      if path
        child[path]
      else
        child
      end
    end

    # Builds all children and sets instance variable named by name of namespace with the results.
    def build_self(build_once = true)
      Namespace.root.add_variable(path, @children.collect {|p| p.last.build }.uniq)
    end
  end
end
