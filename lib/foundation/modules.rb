# frozen_string_literal: true

require_relative "modules/manifest"
require_relative "modules/registry"
require_relative "modules/omit"

module Foundation
  module Modules
    def self.registry(root: Dir.pwd)
      Registry.new(root)
    end

    def self.available?(name, root: Dir.pwd)
      Registry.new(root).available?(name)
    end

    # Omit one or more modules. Prefer a single invocation with every name
    # when dropping several modules — it is order-independent and matches
    # sequential omit A then B (and B then A) byte-for-byte.
    def self.omit!(*names, root: Dir.pwd)
      Omit.new(root: root, names: names).call
    end
  end
end
