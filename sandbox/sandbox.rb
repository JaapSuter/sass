sandbox_dir = File.expand_path File.dirname(__FILE__)
sass_lib_dir = File.expand_path File.join File.dirname(__FILE__), '../lib'

$LOAD_PATH.unshift sass_lib_dir

require 'sass'
require 'facets/module/attr_class_accessor'

module Jaap
  module SassExtensions
    def get_responsive_values(property)
      property = unwrap property
      values = responsive_conditions[property]
      values = values.uniq.sort
      values = values.reverse if property.start_with? 'max'
      to_sass values
    end

    def respond_to(property, value)
      self.responsive_property = property = unwrap property
      self.responsive_value = value = unwrap value

      self.responsive_conditions[property] << value

      puts "#{self.responsive_property}: #{self.responsive_value}"
      to_sass true
    end

    def respond(property, value)
      property = unwrap property
      value = unwrap value
      responsive_conditions[property] << value
      to_sass case self.responsive_property
        when '_all' then true
        when '_none' then false
        when property then value == self.responsive_value
        else
          # puts "#{self.responsive_property} ?= #{self.property}"
          false
        end

      # case self.phase
      #   when :capture
      #     self.responsive_props << MediaQuery.new(prop.value, val.value)
      #     to_sass true
      #   when :responding_to_default
      #     to_sass false
      #   when :responding
      #     puts "#{self.min_width}, #{self.max_width} ?= #{prop.value}, #{val.value}"
      #     case prop.value
      #     when 'min-width'
      #       to_sass val.value <= self.max_width
      #     when 'max-width'
      #       to_sass val.value >= self.min_width
      #     else
      #       puts "Unknown prop.value: #{prop.value}"
      #       to_sass false
      #     end
      #   else
      #     raise Sass::SyntaxError.new("Responsifier got an response phase: #{self.phase}")
      # end
    end

    private
        
    def is_number?(object)
      true if Float(object) rescue false
    end
    
    def is_bool?(object)
      !!object == object
    end       
    
    def to_sass(obj)
      if obj.kind_of?(Struct)
        to_sass obj.each.to_a
      elsif obj.kind_of?(Array)
        arr = obj.map! { |ar| to_sass(ar) }
        Sass::Script::List.new(arr, :space)
      elsif is_number?(obj)
        Sass::Script::Number.new(obj)
      elsif is_bool?(obj)
        Sass::Script::Bool.new(obj)
      elsif obj.nil?
        Sass::Script::String.new("!ERROR, obj == nil")
      else
        Sass::Script::Parser.parse obj, 0, 0
      end
    end

    def unwrap(*v)
      v = v.map { |e|
        if e.is_a? Fixnum
          e
        elsif e.respond_to? 'value'
          e.value
        else
          e
        end
      }
      v.length == 1 ? v.first : v
    end
  end
end

module Sass::Script::Functions
  class EvaluationContext
    attr_class_accessor :responsive_conditions
    attr_class_accessor :responsive_property
    attr_class_accessor :responsive_value

    self.responsive_conditions = Hash.new { |hash, key| hash[key] = Array.new }
    self.responsive_property = nil
    self.responsive_value = nil
  end

  include Jaap::SassExtensions
end

src_scss = File.join sandbox_dir, 'src.scss'
dst_css = File.join sandbox_dir, 'dst.css'
  
begin
  engine = Sass::Engine.new (File.read src_scss), :syntax => :scss

  srcss = engine.render
  
  File.open(dst_css, 'w') { |file| file.write srcss }

rescue Exception => e
  puts "Error: #{e}"
  puts e.backtrace.join("\n")
  exit -1
end

puts "Done, all good."
exit 0


# class MediaQuery < Struct.new(:property, :value)
#   def <=>(other)
#     if self[:property] != other[:property]
#       self[:property] <=> other[:property]
#     else
#       if self[:property].start_with? 'min'
#         self[:value] <=> other[:value]
#       else
#         other[:value] <=> self[:value]
#       end
#     end
#   end
# end