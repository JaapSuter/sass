# A visitor for spitting a tree to the console
class Sass::Tree::Visitors::Log < Sass::Tree::Visitors::Base
  
  def self.visit(root, msg)
    puts "---- #{msg} ----"
    super root
  end

  protected
  
  def visit(node)
    @indent = 0 if @indent.nil?
    puts ' ' * @indent + node_name(node)
    super(node)
  rescue Sass::SyntaxError => e
    e.modify_backtrace(:filename => node.filename, :line => node.line)
    raise e
  end
  
  def visit_children(parent)
    @indent += 1
    super(parent)
    # parent.children = super.flatten
    @indent -= 1
  end
end
