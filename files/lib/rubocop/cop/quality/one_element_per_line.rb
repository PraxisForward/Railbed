# typed: strict
# frozen_string_literal: true

require "rubocop"
require "sorbet-runtime"

module RuboCop
  module Cop
    module Quality
      class OneElementPerLine < RuboCop::Cop::Base
        extend T::Sig
        extend RuboCop::Cop::AutoCorrector

        CALL_MSG = "Put each argument on its own line once the call breaks after its opening bracket."
        HASH_MSG = "Put each key on its own line once the hash breaks after its opening brace."

        sig { params(node: RuboCop::AST::SendNode).void }
        def on_send(node)
          return unless node.parenthesized?

          arguments = node.arguments
          last = arguments.last
          arguments = arguments[0...-1] + last.children if last&.hash_type? && !last.braces?
          check(node, arguments, CALL_MSG)
        end
        alias on_csend on_send

        sig { params(node: RuboCop::AST::HashNode).void }
        def on_hash(node)
          check(node, node.children, HASH_MSG) if node.braces?
        end

        private

        sig { params(node: RuboCop::AST::Node, elements: T::Array[RuboCop::AST::Node], message: String).void }
        def check(node, elements, message)
          return unless one_line_after_break?(node, elements)

          indent = "\n#{' ' * elements.fetch(0).loc.column}"
          elements.drop(1).each_with_index do |element, index|
            gap = elements.fetch(index).source_range.end.join(element.source_range.begin)
            add_offense(element, message:) { |corrector| corrector.replace(gap, ",#{indent}") }
          end
        end

        sig { params(node: RuboCop::AST::Node, elements: T::Array[RuboCop::AST::Node]).returns(T::Boolean) }
        def one_line_after_break?(node, elements)
          first = elements.first
          return false if first.nil? || heredoc?(elements)

          first.first_line != node.loc.begin.line && first.first_line == elements.fetch(-1).last_line
        end

        sig { params(elements: T::Array[RuboCop::AST::Node]).returns(T::Boolean) }
        def heredoc?(elements)
          elements.any? { |element| element.each_node(:any_str).any?(&:heredoc?) }
        end
      end
    end
  end
end
