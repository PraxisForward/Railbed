# typed: strict
# frozen_string_literal: true

require "rubocop"
require "sorbet-runtime"

module RuboCop
  module Cop
    module Quality
      class NoDirectEnv < RuboCop::Cop::Base
        extend T::Sig

        MSG = "Read settings through Credentials.dig instead of ENV."

        sig { params(node: RuboCop::AST::ConstNode).void }
        def on_const(node)
          add_offense(node) if node.short_name == :ENV && [ nil, :cbase ].include?(node.namespace&.type)
        end
      end
    end
  end
end
