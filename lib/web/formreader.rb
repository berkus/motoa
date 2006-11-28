class FormReader #:nodoc: all
  attr_accessor :html
  alias :body :html
  attr_reader :url
  attr_accessor :forms
  def initialize( html )
    @html = html
    @parsed = nil
    @url = ""
  end

  def get_content
    html
  end
  
  def forms
    @forms ||= { }
  end

  def [] (key)
    # ugly ugly ugly
    form_elements( key )
    forms[key]
  end

  def form_elements( name )
    unless( forms[name] )
      html_tree.get_elements("form").each{ |form|
        if (name == form.attribute("name"))
          forms[name] ||= FormElements.new

          forms[name].action = form.attribute("action")

          form.get_elements("input").each{ |e|
            if ["text","hidden","submit","password","file"].include? e.attribute("type") or e.attribute("type").nil?
              forms[name].push_text( e.attribute("name"),
                                     Web.unescape(e.attribute("value")) || "" )
            elsif e.attribute("type") == "checkbox"
              # boolean checkboxes
              #   - assumed if there is no value
              if (e.attribute("value") == "" || e.attribute("value").nil?)
                forms[name].push( e.attribute("name"),
                                  if (e.attribute("checked"))
                                    true
                                  else
                                    false
                                  end )
              else
                # multi select checkboxes
                select = forms[name].find_select( e.attribute("name") )
                select.multiple = true
                select.push_option(e)
              end
            elsif e.attribute("type") == "radio"
              select = forms[name].find_select( e.attribute("name") )
              select.multiple = false
              select.push_option(e)
            elsif e.attribute("type") == "file"
            end
          }
          form.get_elements("textarea").each{ |e|
            forms[name].push_text e.attribute("name"), e.content.to_s.strip
          }
          form.get_elements("select").each { |e|
            select = Select.new
            select.multiple = e.attribute("multiple") != nil
            e.get_elements("option").each{ |option|
              select.shift_option( option )
            }
            forms[name].push_select e.attribute("name"), select
          }
        end
      }
    end
    forms[name]
  end

  def get_fields( name )
    form_elements(name).get_fields
  end

  def get_options( name )
    form_elements(name).get_options
  end

  def html_tree
    unless (@html_tree)
      p = HTMLTree::Parser.new(true, false)
      p.feed get_content
      @html_tree = p.tree
    end
    @html_tree
  end
  
  
  def merge_fields( name, edited_fields )
    form_elements(name).merge_fields(edited_fields)
  end

  class Option
    attr_accessor :value, :selected
    def initialize( value, selected )
      @value = value; @selected = selected
    end
  end

  class Select
    attr_accessor :options, :multiple
    def initialize
      @options = Array.new
      @multiple = false
    end
    
    def shift_option( option )
      options.unshift(make_option_from_element(option))
    end

    def push_option( option )
      options.push(make_option_from_element(option))
    end

    def make_option_from_element( element )
      value = element.attribute("value")
      unless value
        value = element.content.to_s
        value.gsub!( /<[^>]*>/, "" )
        value.strip!
      end
      Option.new( value,
                  element.attribute("selected") || \
                  element.attribute("checked") )
    end

    def each
      options.each{ |option|
        yield option.value if option.selected
      }
    end

    include Enumerable

    def == other
      if other.kind_of?(String) && self.to_a.length == 1
        other == self.to_a[0]
      else
        other == self.to_a
      end
    end

    # these functions are the interface for assert_includes
    # we delegate to the array... but also answer to the options hash
    def has_key?(index)
      self.to_a.has_key?(index)
    end

    def __index(key)
      self.to_a.__index(key)
    end
    
    def compare_includes? haystack, prefix=[]
      self.to_a.compare_includes? haystack, prefix
    end

  end

  class FormElements
    attr_reader :fields
    attr_accessor :action

    def initialize
      @fields = {}
    end
    
    def get_fields
      crushedFields = { }
      @fields.each{ |k,v|
        v = v.collect { |v1|
          if v1.kind_of? Select
            v1.to_a.sort
          else
            v1
          end
        }.flatten
        crushedFields[k] = v
      }
      Web::Testing::MultiHashTree.new(crushedFields).fields
      #crushedFields
    end
    
    def get_options
      all_options = { }
      @fields.each{ |k,v|
        v.each { |field|
          if (field.kind_of? Select)
            all_options[k] = field.options.collect{ |o|
              o.value
            }
          end
        }
      }
      all_options
    end

    def merge_fields( edited_fields )
      merged = Marshal.load( Marshal.dump( @fields ) )
      
      edited_fields.each{ |k,v|
        # normalize inputs
        k = k.to_s
        v = [v] unless v.kind_of? Array

        # guard against errors
        if merged[k].nil?
          raise Web::Testing::FieldNotFoundException.new( "Element named #{k} not present on form" )
        end

        if (v.size > merged[k].size)
          raise FormMergeError.new( "Only #{merged[k].size} elements on form; " +
                                            "Can't merge with #{v.size} new values" )
        end

        v.each_with_index{ |v, i|
          pristine = @fields[k][i]
          target   = merged[k][i]

          if (pristine.kind_of? Select)
            # guard against improperly submitted values
            unless v.kind_of? Hash
              raise FormMergeError.new( "Values for select elements must be merged in by using merge('#{k}'=>select('#{v}')" )
            end

            # guard against merging multiple
            # values into single select
            if (pristine.multiple == false) & (v.keys.length > 1 )
              raise FormMergeError.new( "Trying to merge multiple [#{ v.inspect }] into single select[#{ k }]" )
            end

            # selects must be merged with a hash
            v.each{ |value, flag|
              # guard against merging nonexistent option
              unless pristine.options.find{ |e|
                  e.value == value
                }
                raise FormMergeError. \
                new("Form doesn't have an option for #{value}")
              end
              
              
              # turn off everything else for single selects
              
              unless target.multiple || flag == false
                target.options.each { |o|
                  o.selected = false
                }
              end
            
              # merge select fields
              target.options.find{ |e|
                e.value == value
              }.selected = flag
            }
            
          else
            merged[k][i] = v
          end
        }
      }

      # delete unchecked checkboxes
      merged.delete_if{ |k,v|
        v.delete_if{ |e|
          e == false
        }
        v.size == 0
      }



      # flatten out select elements
      merged.each{ |k,v|
        merged[k] = v.collect{ |e|
          if (e.kind_of? Select)
            e.to_a
          else
            e
          end
        }.flatten
      }
      merged
    end
    
    def push( name, value )
      @fields[name] ||= []
      @fields[name].push value
    end

    def find_select( name )
      select = if (fields[name])
                 fields[name].find{ |e|
                   e.kind_of? Select
                 }
               end
      unless select
        select = Select.new
        push name, select
      end
      select
    end
    
    alias :push_text :push
    alias :push_select :push
    
  end
end

class FormMergeError < Exception #:nodoc: all
end
