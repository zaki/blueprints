module Blueprints
  class Buildable
    attr_reader :name
    attr_accessor :namespace

    def initialize(name)
      @name, parents = parse_name(name)
      depends_on(*parents)

      Namespace.root.add_child(self) if Namespace.root 
    end

    def depends_on(*scenarios)
      @parents = (@parents || []) + scenarios.map{|s| s.to_sym}
    end

    def build
      namespace.build_parent_plans
      build_parent_plans
      build_plan
    end

    protected

    def build_parent_plans
      @parents.each do |p|
        parent = begin
          namespace[p]
        rescue PlanNotFoundError
          Namespace.root[p]
        end

        parent.build_parent_plans
        parent.build_plan
      end
    end

    def parse_name(name)
      case name
        when Hash
          return name.keys.first.to_sym, [name.values.first].flatten.map{|sc| parse_name(sc).first}
        when Symbol, String
          name = name.to_sym unless name == ''
          return name, []
        else
          raise TypeError, "Pass plan names as strings or symbols only, cannot build plan #{name.inspect}"
      end
    end
  end
end