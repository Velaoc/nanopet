# frozen_string_literal: true

require "fileutils"
require "set"
require "yaml"
require_relative "registry"

module Foundation
  module Modules
    # Generation-time filesystem surgery: delete a module's owned paths and
    # strip its host-file contributions. Plain Ruby — no Rails boot.
    class Omit
      class Error < StandardError; end

      RESULT = Struct.new(:removed_paths, :rewritten_files, :residue, keyword_init: true)

      # Paths that may still mention a module by name after omit (design, tooling,
      # product narrative). Code under app/config/db/test must still be clean.
      ALLOWLIST_PREFIXES = [
        "docs/",
        "README.md",
        "lib/foundation/modules/",
        "bin/foundation-modules",
        "test/lib/foundation/modules_test.rb",
        "PROVENANCE.md",
        "SPEC.md"
      ].freeze

      SCAN_ROOTS = %w[app bin config db docs lib script test].freeze

      def initialize(root:, names:)
        @root = File.expand_path(root)
        @registry = Registry.new(@root)
        @names = Array(names).flatten.map(&:to_s)
        raise Error, "omit requires at least one module name" if @names.empty?

        # Sorted so multi-omit RESULT paths and rewrite order stay stable
        # regardless of CLI argument order.
        @names = @names.uniq.sort
        @manifests = @names.map { |name| @registry.fetch(name) }
        @omit_set = @manifests.map(&:name).to_set
      end

      def call
        assert_dependencies_ok!
        removed = []
        @manifests.each do |manifest|
          removed.concat(delete_owned_paths(manifest))
          removed.concat(delete_manifest(manifest))
        end
        rewritten = []
        rewritten.concat(strip_markers_in_tree)
        rewritten.concat(strip_css_prefix_lines)
        rewritten.concat(strip_foundation_yml_keys)
        rewritten.concat(strip_schema_tables)
        residue = residue_hits
        if residue.any?
          raise Error, "residue remains after omitting #{@names.join(', ')}:\n#{residue.join("\n")}"
        end

        RESULT.new(removed_paths: removed.uniq.sort, rewritten_files: rewritten.uniq.sort, residue: [])
      end

      def self.residue_for(root:, name:, patterns:)
        new(root: root, names: [ name ]).send(:scan_residue, name, patterns)
      end

      # Pure marker surgery used by tests and by strip_markers_in_tree. Removing
      # one name must never consume another name's markers (adjacent or not).
      def self.strip_markers(source, *names)
        text = source.dup
        names.flatten.map(&:to_s).uniq.each do |name|
          text = strip_comment_blocks(text, name)
          text = collapse_tagged_conditionals(text, name)
        end
        text
      end

      # Block markers. Do not use the /x flag — "#" would start a regex comment.
      def self.strip_comment_blocks(text, name)
        n = Regexp.escape(name)
        erb = %r{^[ \t]*<%\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n.*?^[ \t]*<%\#[ \t]*/foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n?}m
        css = %r{^[ \t]*/\*[ \t]*foundation:module[ \t]+#{n}[ \t]*\*/[ \t]*\n.*?^[ \t]*/\*[ \t]*/foundation:module[ \t]+#{n}[ \t]*\*/[ \t]*\n?}m
        hash = %r{^[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n.*?^[ \t]*\#[ \t]*/foundation:module[ \t]+#{n}[ \t]*\n?}m
        text.gsub(erb, "").gsub(css, "").gsub(hash, "")
      end

      # Collapse if/else/end (Ruby or ERB) tagged with foundation:module NAME
      # into the else body only. Tag binding stays on the same line ([^\n]* /
      # [^%]*): a multiline ".*" would let one module's conditional swallow a
      # neighboring module's region when blocks sit adjacent in a host file.
      def self.collapse_tagged_conditionals(text, name)
        n = Regexp.escape(name)
        erb = %r{^[ \t]*<%[ \t]*if\b[^%]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n.*?^[ \t]*<%[ \t]*else[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n(.*?)^[ \t]*<%[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n?}m
        text = text.gsub(erb) { Regexp.last_match(1) }

        erb_if = %r{^[ \t]*<%[ \t]*if\b[^%]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n.*?^[ \t]*<%[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n?}m
        text = text.gsub(erb_if, "")

        ruby = %r{^[ \t]*if\b[^\n]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n.*?^[ \t]*else[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n(.*?)^[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n?}m
        text = text.gsub(ruby) { Regexp.last_match(1) }

        ruby_if = %r{^[ \t]*if\b[^\n]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n.*?^[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n?}m
        text.gsub(ruby_if, "")
      end

      private

      def assert_dependencies_ok!
        @manifests.each do |manifest|
          dependents = @registry.all.select do |m|
            m.depends_on.include?(manifest.name) && !@omit_set.include?(m.name)
          end
          next if dependents.empty?

          raise Error,
            "cannot omit #{manifest.name}: still required by #{dependents.map(&:name).sort.join(', ')}"
        end
      end

      def delete_owned_paths(manifest)
        manifest.paths.filter_map do |relative|
          absolute = File.join(@root, relative)
          next unless File.exist?(absolute) || File.symlink?(absolute)

          FileUtils.rm_rf(absolute)
          relative
        end
      end

      def delete_manifest(manifest)
        relative = "config/foundation/modules/#{manifest.name}.yml"
        absolute = File.join(@root, relative)
        return [] unless File.file?(absolute)

        FileUtils.rm_f(absolute)
        [ relative ]
      end

      def strip_markers_in_tree
        rewritten = []
        names = @manifests.map(&:name)
        each_text_file do |relative, absolute|
          next if allowlisted?(relative)

          original = File.read(absolute, encoding: "UTF-8")
          updated = self.class.strip_markers(original, *names)
          next if updated == original

          File.write(absolute, updated, encoding: "UTF-8")
          rewritten << relative
        end
        rewritten
      end

      def strip_css_prefix_lines
        prefixes = @manifests.flat_map { |m| m.residue_patterns.grep(/\A\./) }.uniq
        return [] if prefixes.empty?

        rewritten = []
        each_text_file do |relative, absolute|
          next unless relative.end_with?(".css")

          original = File.read(absolute, encoding: "UTF-8")
          updated = original.lines.reject { |line| prefixes.any? { |prefix| line.include?(prefix) } }.join
          next if updated == original

          File.write(absolute, updated, encoding: "UTF-8")
          rewritten << relative
        end
        rewritten
      end

      def strip_foundation_yml_keys
        relative = "config/foundation.yml"
        absolute = File.join(@root, relative)
        return [] unless File.file?(absolute)

        original = File.read(absolute, encoding: "UTF-8")
        updated = original.dup
        @manifests.each do |manifest|
          manifest.config_keys.each do |key|
            updated.gsub!(/(?:^[ \t]*\#[^\n]*\n)*^[ \t]*#{Regexp.escape(key)}:[^\n]*\n(?:(?:^[ \t]*\#[^\n]*\n)|(?:^[ \t]+-[^\n]*\n))*/m, "")
          end
        end
        updated.gsub!(/\n{3,}/, "\n\n")
        return [] if updated == original

        File.write(absolute, updated, encoding: "UTF-8")
        [ relative ]
      end

      def strip_schema_tables
        relative = "db/schema.rb"
        absolute = File.join(@root, relative)
        return [] unless File.file?(absolute)

        prefixes = @manifests.flat_map(&:table_prefixes).uniq
        return [] if prefixes.empty?

        original = File.read(absolute, encoding: "UTF-8")
        updated = original.dup
        prefixes.each do |prefix|
          p = Regexp.escape(prefix)
          updated.gsub!(/^  create_table "#{p}[^"]*", force: :cascade do \|t\|.*?^  end\n+/m, "")
          updated.gsub!(/^  add_foreign_key "#{p}[^"]*".*\n/, "")
          updated.gsub!(/^  add_foreign_key "[^"]*", "#{p}[^"]*".*\n/, "")
        end
        return [] if updated == original

        File.write(absolute, updated, encoding: "UTF-8")
        [ relative ]
      end

      def residue_hits
        @manifests.flat_map { |manifest| scan_residue(manifest.name, manifest.residue_patterns) }
      end

      def scan_residue(name, patterns)
        hits = []
        compiled = patterns.map { |p| [ p, Regexp.new(Regexp.escape(p)) ] }
        marker = /foundation:module[ \t]+#{Regexp.escape(name)}\b/

        each_text_file do |relative, absolute|
          next if allowlisted?(relative)

          content = File.read(absolute, encoding: "UTF-8")
          if marker.match?(content)
            hits << "#{relative}: leftover module marker"
          end
          compiled.each do |label, regex|
            next unless regex.match?(content)

            hits << "#{relative}: matches #{label.inspect}"
          end
        end
        hits
      end

      def allowlisted?(relative)
        ALLOWLIST_PREFIXES.any? { |prefix| relative == prefix || relative.start_with?(prefix) }
      end

      def each_text_file
        SCAN_ROOTS.each do |top|
          base = File.join(@root, top)
          next unless File.directory?(base)

          Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH).each do |absolute|
            next unless File.file?(absolute)
            next if File.basename(absolute).start_with?(".")
            next if binary?(absolute)

            relative = absolute.delete_prefix(@root + File::SEPARATOR)
            yield relative, absolute
          end
        end
      end

      def binary?(path)
        return true if path.end_with?(".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".woff", ".woff2", ".ttf", ".otf", ".zip", ".gz")

        sample = File.read(path, 512, mode: "rb")
        sample&.include?("\x00")
      rescue Errno::ENOENT
        true
      end
    end
  end
end
