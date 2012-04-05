# A visitor for post-capture responding. Note that it does not
# derive from Sass::Tree::Visitors::Base. That's because internally
# it ends up walking two trees in parallel (comparing them), which
# means the default base class behaviour isn't really that useful.
class Sass::Tree::Visitors::Responsify
  
  def self.visit(root)

    children = root.children

    grouped = children.group_by do |c|
      if c.is_a? Sass::Tree::MediaNode
        raise Sass::SyntaxError.new("Responsifier can't have more than one condition in a query so far...") if c.query.queries.length > 1

        query = c.query.queries.first
        if query.expressions.empty?
          query.type.first || ''
        elsif query.expressions.first.is_a? Sass::Media::Expression
          expr = query.expressions.first
          expr.resolved_name
        else
          raise Sass::SyntaxError.new "Responsifier encountered media query of unexpected (or unsupported) format."
        end
      else
        'rest'
      end
    end

    all_node = (grouped['_all'] || []).first
    none_node = (grouped['_none'] || []).first
    min_width_nodes = grouped['min-width'] || []
    max_width_nodes = grouped['max-width'] || []
    rest_nodes = grouped['rest'] || []

    if none_node
      state = Sass::Tree::Visitors::DeepCopy.visit(none_node)
      max_width_nodes.each { |max_width_node| new.send :visit, max_width_node, state }
    end

    if none_node
      state = Sass::Tree::Visitors::DeepCopy.visit(none_node)
      min_width_nodes.each { |min_width_node| new.send :visit, min_width_node, state }
    end

    root.children = (none_node ? none_node.children : []) + max_width_nodes + min_width_nodes + rest_nodes
  end

  protected

  def node_name(node)
    Class.new(Sass::Tree::Visitors::Base) do
      def node_name(node) super end
      return new.node_name node
    end
  end

  def visit(node, state)
    raise SyntaxError.new "Responsifier type mismatch between node and state." unless state.nil? || state.class == node.class
    method = "visit_#{node_name node}"
    if self.respond_to?(method)
      self.send(method, node, state) { visit_children(node, state) }
    else
      visit_children(node, state)
      return node, state
    end
  end
  
  def visit_children(node, state)
    node.children = node.children.select do |child|
      match, index = find_matching_state child, (state.nil? ? [] : state.children)
      child, match = visit child, match

      if index.nil?
        state.children << match unless state.nil?
      elsif match.nil?
        state.children.delete_at index unless state.nil?
      else
        state.children[index] = match unless state.nil?
      end

      child
    end
    
    # parent.children = remaining_children.flatten
    # parent
  end

  def visit_prop(node, state)

    yield node, state

    if state.nil?
      return node, node
    else
      raise SyntaxError.new("Responsifier expected a property node or nothing at all.") unless state.is_a? Sass::Tree::PropNode
      raise SyntaxError.new("Responsifier assumes a resolved property node will have no children, this one does.") unless state.children.empty?
      raise SyntaxError.new("Responsifier reached two properties whose names don't match: #{state.resolved_name} != #{node.resolved_name}") unless state.resolved_name == node.resolved_name
      
      puts "#{node.resolved_name}: #{node.resolved_value} ?= #{state.resolved_name}: #{state.resolved_value}"
      
      if state.resolved_value == node.resolved_value
        return nil, state
      else
        return node, node
      end
    end
  end

  def visit_rule(node, state)

    yield node, state

    node = nil if node.children.empty?
    return node, state
  end

  private

  def find_matching_state(node, candidates)
    index = candidates.rindex { |candidate|

      if candidate.class != node.class
        false
      else
        case candidate
        when Sass::Tree::RuleNode
          candidate.resolved_rules == node.resolved_rules
        when Sass::Tree::PropNode
          candidate.resolved_name == node.resolved_name
        else
          raise SyntaxError.new( "Responsifier ran into a node that was not a rule or property (but a #{node.class}), and thus panicked.")
        end
      end
    }

    if index.nil?
      return nil, nil
    else
      return candidates[index], index
    end
  end
end
