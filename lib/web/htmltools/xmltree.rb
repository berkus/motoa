#!/usr/bin/ruby
# This is an HTML parser that builds an element tree for further
# processing. Attributes and data are also stored.
# The storage is that of REXML, which is required.
#
# Typical usage is:
#   parser = HTMLTree::XMLParser.new(false, false)
#   parser.parse_file_named('whatever.html')
#   # then you have the tree built..
#   parser.tree # is a REXML::Document
#
# Copyright:: Copyright (C) 2002, Ned Konz <ned@bike-nomad.com>
# License::   Ruby's
# CVS ID::    $Id: tree.rb,v 1.14 2002/06/04 01:55:59 ned Exp $

require 'web/htmltools/tags'
require 'web/htmltools/stparser'
require 'rexml/element'
require 'rexml/document'

# REXML::Child
#   REXML::XMLDecl
#   REXML::Instruction
#   REXML::Text
#   REXML::Comment
#   REXML::Entity
#   REXML::Parent
#     REXML::Element (+REXML::Namespace)
#       REXML::Document
#     REXML::DocType
#
# This is a tree building HTML parser that makes XML.
module HTMLTree #:nodoc: all
  class XMLParser < HTML::StackingParser

    # verbose::  if true, will warn to $stderr on unknown
    # tags/entities/characters, as well as missing end tags and extra end
    # tags.
    # strip_white:: if true, remove all non-essential whitespace. Note
    # that there are browser bugs that may cause this to change the
    # appearance of HTML (even though it shouldn't by the standard).
    def initialize(verbose=false, strip_white=true)
      super
      reset
    end

    # Reset this parser so that it can parse a new document.
    def reset
      super
      @rootNode = @currentNode = REXML::Document.new()
    end

    # Return the document that was built. This will be an
    # REXML::Document that represents the whole document. The \<html>
    # node is a child of this.
    def document
      @rootNode
    end

    def tree
      document()
    end

    # Return the root of the document, if any.
    def root
      @rootNode.root()
    end

    # Return the <html> node, if any.
    def html
      @rootNode.root.elements['html']
    end

    # no user-serviceable parts inside...
    # though you can subclass carefully.
    private

    def add_child_to_current(tag, attrs)
      node = REXML::Element.new(tag, @currentNode)
      attrs.each { |a| node.attributes[a[0]] = a[1] }
      node
    end

    # callbacks

    # add a child to the current node and descend
    def handle_start_tag(tag, attrs)
      node = add_child_to_current(tag, attrs)
      @rootNode = node unless @rootNode
      @currentNode = node
    end

    # go up to parent
    def handle_end_tag(tag)
      @currentNode = @currentNode.parent
    end

    # add a child to the current node
    def handle_empty_tag(tag, attrs)
      add_child_to_current(tag, attrs)
    end

    # Add a child to the current node and descend
    # Assume that the unknown tag has an end tag.
    def handle_unknown_tag(tag, attrs)
      super
      handle_start_tag(tag, attrs)
    end

    # go up to parent
    def handle_missing_end_tag(tag)
      super
      handle_end_tag(tag)
    end

    # ignore
    def handle_extra_end_tag(tag)
      super
    end

    def handle_cdata(data)
      REXML::Text.new(data, !@stripWhitespace, @currentNode)
    end

    def handle_script(data)
      REXML::Comment.new(data, @currentNode)
    end

    def handle_unknown_character(name)
      super # that is, do nothing
    end

    def handle_unknown_entity(name)
      super # that is, do nothing
    end

    def handle_comment(data)
      super # strip white
      REXML::Comment.new(data, @currentNode)
    end

    def handle_special(data)
      REXML::DocType.new(data, @currentNode)  # TODO
    end

  end
end

if $0 == __FILE__
  $stdout.sync = true

  class TestStackingParser < HTMLTree::XMLParser #:nodoc: all
    $DEBUG = false
    p = TestStackingParser.new(true, false)
    p.parse_file_named(ARGV[0] || 'ebay.html')
    File.open('xx.html', 'w') { |of|
      p.document.write(of)
    }
  end
end
