# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "uri"

# Generation-time module composition (docs/MODULES.md). Default checkouts keep
# every included module; omit is opt-in filesystem surgery reversible from git.
class FoundationModulesTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/foundation-modules").to_s

  setup do
    @root = Dir.mktmpdir("foundation-modules-test")
  end

  teardown { FileUtils.remove_entry(@root, true) }

  # These exercise the mechanism through the storefront, the only module
  # declared today. A generated application that omitted it still ships this
  # file, so they skip rather than fail there — otherwise the composition
  # system's own tests become the residue it exists to prevent. Any future
  # module gets the same treatment for free.
  def skip_without_storefront
    return if Foundation::Modules.registry(root: Rails.root).available?("storefront")

    skip "storefront module is not declared in this tree (omitted at generation)"
  end

  test "registry lists the storefront module as included by default" do
    skip_without_storefront
    registry = Foundation::Modules.registry(root: Rails.root)

    assert registry.available?("storefront")
    storefront = registry.fetch("storefront")
    assert_equal "included", storefront.default
    assert_includes storefront.paths, "app/models/foundation/storefront"
    assert_includes storefront.table_prefixes, "storefront_"
    assert Foundation.module_available?("storefront")
  end

  test "list command prints declared modules" do
    skip_without_storefront
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, SCRIPT, "list", "--root", Rails.root.to_s)

    assert_predicate status, :success?, stderr
    assert_match(/storefront\tdefault=included/, stdout)
  end

  test "omitting storefront leaves no structural residue and keeps core files" do
    skip_without_storefront
    mirror_template_into!(@root)

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, SCRIPT, "omit", "storefront", "--root", @root
    )

    assert_predicate status, :success?, "#{stderr}\n#{stdout}"
    assert_match(/Omitted module storefront/, stdout)

    refute File.exist?(File.join(@root, "app/models/foundation/storefront"))
    refute File.exist?(File.join(@root, "app/controllers/foundation/storefront"))
    refute File.exist?(File.join(@root, "db/migrate/20260811060001_create_storefront.rb"))
    refute File.exist?(File.join(@root, "config/foundation/modules/storefront.yml"))
    refute File.exist?(File.join(@root, "docs/STOREFRONT.md"))
    refute File.exist?(File.join(@root, "lib/foundation/demo_seeds.rb"))
    refute File.exist?(File.join(@root, "test/integration/storefront_flows_test.rb"))

    schema = File.read(File.join(@root, "db/schema.rb"), encoding: "UTF-8")
    refute_match(/create_table "storefront_/, schema)
    refute_match(/add_foreign_key "storefront_/, schema)

    foundation_yml = File.read(File.join(@root, "config/foundation.yml"), encoding: "UTF-8")
    refute_match(/storefront_enabled/, foundation_yml)
    refute_match(/storefront_fulfillment_mode/, foundation_yml)

    routes = File.read(File.join(@root, "config/routes.rb"), encoding: "UTF-8")
    refute_match(%r{foundation/storefront}, routes)
    refute_match(/storefront_stripe_webhook/, routes)
    assert_match(%r{root "foundation/home#show"}, routes)

    user = File.read(File.join(@root, "app/models/user.rb"), encoding: "UTF-8")
    refute_match(/storefront_orders/, user)
    refute_match(/Foundation::Storefront/, user)

    seeds = File.read(File.join(@root, "db/seeds.rb"), encoding: "UTF-8")
    refute_match(/DemoSeeds/, seeds)

    recurring = File.read(File.join(@root, "config/recurring.yml"), encoding: "UTF-8")
    refute_match(/Storefront::/, recurring)

    layout = File.read(File.join(@root, "app/views/layouts/application.html.erb"), encoding: "UTF-8")
    refute_match(/storefront_cart_path/, layout)
    nav = File.read(File.join(@root, "app/helpers/foundation/navigation_helper.rb"), encoding: "UTF-8")
    refute_match(/storefront_cart_path/, nav)
    refute_match(/storefront_products_path/, nav)
    # Platform surface still offers Billing once the storefront module is gone.
    assert_match(/Billing/, nav)

    css = File.read(File.join(@root, "app/assets/stylesheets/material_system.css"), encoding: "UTF-8")
    refute_match(/\.storefront-/, css)

    %w[
      app/models/user.rb
      config/routes.rb
      app/views/layouts/application.html.erb
      config/recurring.yml
      config/allgood.rb
    ].each do |relative|
      content = File.read(File.join(@root, relative), encoding: "UTF-8")
      refute_match(/foundation:module storefront/, content, relative)
    end

    assert File.exist?(File.join(@root, "app/models/user.rb"))
    assert File.exist?(File.join(@root, "config/routes.rb"))
    assert File.exist?(File.join(@root, "lib/foundation/modules/omit.rb"))
    assert File.exist?(File.join(@root, "docs/MODULES.md"))
  end

  test "default tree still has the storefront module on disk" do
    skip_without_storefront
    assert File.directory?(Rails.root.join("app/models/foundation/storefront"))
    assert File.file?(Rails.root.join("config/foundation/modules/storefront.yml"))
    assert_equal true, Rails.configuration.x.foundation[:storefront_enabled]
  end

  def skip_without_crm
    return if Foundation::Modules.registry(root: Rails.root).available?("crm")

    skip "crm module is not declared in this tree (omitted at generation)"
  end

  test "registry lists the crm module as included by default" do
    skip_without_crm
    registry = Foundation::Modules.registry(root: Rails.root)
    assert registry.available?("crm")
    crm = registry.fetch("crm")
    assert_equal "included", crm.default
    assert_includes crm.paths, "app/models/foundation/crm"
    assert_includes crm.table_prefixes, "crm_"
    assert Foundation.module_available?("crm")
  end

  test "omitting crm leaves no structural residue and keeps core files" do
    skip_without_crm
    mirror_template_into!(@root)

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, SCRIPT, "omit", "crm", "--root", @root
    )

    assert_predicate status, :success?, "#{stderr}\n#{stdout}"
    assert_match(/Omitted module crm/, stdout)

    refute File.exist?(File.join(@root, "app/models/foundation/crm"))
    refute File.exist?(File.join(@root, "app/controllers/foundation/crm"))
    refute File.exist?(File.join(@root, "db/migrate/20260811140000_create_crm.rb"))
    refute File.exist?(File.join(@root, "config/foundation/modules/crm.yml"))
    refute File.exist?(File.join(@root, "docs/CRM.md"))
    refute File.exist?(File.join(@root, "test/integration/crm_isolation_test.rb"))

    schema = File.read(File.join(@root, "db/schema.rb"), encoding: "UTF-8")
    refute_match(/create_table "crm_/, schema)
    refute_match(/add_foreign_key "crm_/, schema)

    routes = File.read(File.join(@root, "config/routes.rb"), encoding: "UTF-8")
    refute_match(%r{foundation/crm}, routes)
    refute_match(/crm_root_path/, routes)

    layout = File.read(File.join(@root, "app/views/layouts/application.html.erb"), encoding: "UTF-8")
    refute_match(/crm_root_path/, layout)
    refute_match(/label: "CRM"/, layout)

    helper = File.read(File.join(@root, "test/test_helper.rb"), encoding: "UTF-8")
    refute_match(/crm_test_helper/, helper)

    %w[
      config/routes.rb
      app/views/layouts/application.html.erb
      test/test_helper.rb
    ].each do |relative|
      content = File.read(File.join(@root, relative), encoding: "UTF-8")
      refute_match(/foundation:module crm/, content, relative)
    end

    assert File.exist?(File.join(@root, "app/models/user.rb"))
    assert File.exist?(File.join(@root, "config/routes.rb"))
    assert File.exist?(File.join(@root, "lib/foundation/modules/omit.rb"))
  end

  test "omitting storefront then crm succeeds with clean routes" do
    skip_without_storefront
    skip_without_crm
    mirror_template_into!(@root)

    omit_via_cli!(%w[storefront])
    omit_via_cli!(%w[crm])

    assert_omitted_optional_modules!(@root)
  end

  test "omitting crm then storefront succeeds with clean routes" do
    skip_without_storefront
    skip_without_crm
    mirror_template_into!(@root)

    omit_via_cli!(%w[crm])
    omit_via_cli!(%w[storefront])

    assert_omitted_optional_modules!(@root)
  end

  test "omit order is independent and matches multi-module omit" do
    skip_without_storefront
    skip_without_crm

    root_ab = Dir.mktmpdir("foundation-modules-ab")
    root_ba = Dir.mktmpdir("foundation-modules-ba")
    root_both = Dir.mktmpdir("foundation-modules-both")
    begin
      mirror_template_into!(root_ab)
      mirror_template_into!(root_ba)
      mirror_template_into!(root_both)

      omit_via_cli!(%w[storefront], root: root_ab)
      omit_via_cli!(%w[crm], root: root_ab)

      omit_via_cli!(%w[crm], root: root_ba)
      omit_via_cli!(%w[storefront], root: root_ba)

      omit_via_cli!(%w[storefront crm], root: root_both)

      assert_omitted_optional_modules!(root_ab)
      assert_omitted_optional_modules!(root_ba)
      assert_omitted_optional_modules!(root_both)

      tree_ab = snapshot_tree(root_ab)
      tree_ba = snapshot_tree(root_ba)
      tree_both = snapshot_tree(root_both)

      assert_equal tree_ab.keys, tree_ba.keys
      assert_equal tree_ab.keys, tree_both.keys
      tree_ab.each do |relative, digest|
        assert_equal digest, tree_ba[relative], "storefront→crm vs crm→storefront differ at #{relative}"
        assert_equal digest, tree_both[relative], "sequential vs multi-omit differ at #{relative}"
      end
    ensure
      FileUtils.remove_entry(root_ab, true)
      FileUtils.remove_entry(root_ba, true)
      FileUtils.remove_entry(root_both, true)
    end
  end

  test "stripping one module leaves an adjacent module's markers intact" do
    source = <<~RUBY
      # foundation:module alpha
      alpha_only
      # /foundation:module alpha
      # foundation:module beta
      beta_only
      # /foundation:module beta
      if flag # foundation:module alpha
        alpha_branch
      else # foundation:module alpha
        core_branch
      end # foundation:module alpha
    RUBY

    without_alpha = Foundation::Modules::Omit.strip_markers(source, "alpha")
    assert_includes without_alpha, "# foundation:module beta"
    assert_includes without_alpha, "beta_only"
    assert_includes without_alpha, "# /foundation:module beta"
    refute_match(/foundation:module alpha/, without_alpha)
    assert_includes without_alpha, "core_branch"
    refute_includes without_alpha, "alpha_only"
    refute_includes without_alpha, "alpha_branch"

    without_beta = Foundation::Modules::Omit.strip_markers(source, "beta")
    assert_includes without_beta, "# foundation:module alpha"
    assert_includes without_beta, "alpha_only"
    assert_includes without_beta, "# /foundation:module alpha"
    refute_match(/foundation:module beta/, without_beta)
    assert_includes without_beta, "if flag # foundation:module alpha"
  end

  test "after omitting every optional module the application boots and its suite passes" do
    skip_without_storefront
    skip_without_crm

    full = Dir.mktmpdir("foundation-modules-full-omit")
    begin
      mirror_full_application_into!(full)
      names = Foundation::Modules.registry(root: full).all.map(&:name)
      assert_operator names.length, :>=, 2
      omit_via_cli!(names, root: full)
      assert_omitted_optional_modules!(full)

      env = omitted_app_env(full)
      prepare_omit_database!(env, full)
      boot_out, boot_err, boot_status = Open3.capture3(
        env,
        RbConfig.ruby, File.join(full, "bin/rails"), "runner",
        "puts(Rails.application.class.name)",
        chdir: full
      )
      assert_predicate boot_status, :success?, "boot failed:\n#{boot_err}\n#{boot_out}"
      assert_match(/Application/, boot_out)

      test_out, test_err, test_status = Open3.capture3(
        env.merge("PARALLEL_WORKERS" => "1"),
        RbConfig.ruby, File.join(full, "bin/rails"), "test",
        chdir: full
      )
      assert_predicate test_status, :success?, "omitted suite failed:\n#{test_err}\n#{test_out}"
    ensure
      FileUtils.remove_entry(full, true)
      system("dropdb", "--if-exists", "vela_foundation_omit_test", out: File::NULL, err: File::NULL)
    end
  end

  private

  def omit_via_cli!(names, root: @root)
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, SCRIPT, "omit", *names, "--root", root
    )
    assert_predicate status, :success?, "#{stderr}\n#{stdout}"
    stdout
  end

  def assert_omitted_optional_modules!(root)
    refute File.exist?(File.join(root, "config/foundation/modules/storefront.yml"))
    refute File.exist?(File.join(root, "config/foundation/modules/crm.yml"))
    refute File.exist?(File.join(root, "app/models/foundation/storefront"))
    refute File.exist?(File.join(root, "app/models/foundation/crm"))

    routes_path = File.join(root, "config/routes.rb")
    routes = File.read(routes_path, encoding: "UTF-8")
    refute_match(/foundation:module/, routes)
    refute_match(%r{foundation/storefront}, routes)
    refute_match(%r{foundation/crm}, routes)
    assert_match(%r{root "foundation/home#show"}, routes)
    assert_nil syntax_error_for(routes_path), "routes.rb must parse after omit"

    %w[
      app/models/user.rb
      app/views/layouts/application.html.erb
      config/routes.rb
      test/test_helper.rb
    ].each do |relative|
      path = File.join(root, relative)
      next unless File.file?(path)

      content = File.read(path, encoding: "UTF-8")
      refute_match(/foundation:module (storefront|crm)/, content, relative)
    end
  end

  def syntax_error_for(path)
    _, stderr, status = Open3.capture3(RbConfig.ruby, "-c", path)
    return nil if status.success?

    stderr
  end

  def snapshot_tree(root)
    files = {}
    Dir.chdir(root) do
      Dir.glob("**/*", File::FNM_DOTMATCH).each do |relative|
        next if relative == "." || relative == ".."
        next if File.directory?(relative)
        next if relative.start_with?(".git/", "tmp/", "log/", "storage/")

        files[relative] = File.read(relative, mode: "rb")
      end
    end
    files
  end

  def mirror_template_into!(destination)
    %w[app bin config db docs lib script test README.md SPEC.md PROVENANCE.md].each do |entry|
      source = Rails.root.join(entry)
      next unless File.exist?(source)

      FileUtils.cp_r(source, File.join(destination, entry))
    end

    %w[
      test/fixtures/files
      app/assets/builds
      app/assets/images
      app/assets/fonts
      tmp log storage
    ].each do |relative|
      FileUtils.rm_rf(File.join(destination, relative))
    end
  end

  def mirror_full_application_into!(destination)
    Dir.children(Rails.root).each do |entry|
      next if %w[.git tmp log storage node_modules coverage .bundle vendor].include?(entry)

      FileUtils.cp_r(Rails.root.join(entry), File.join(destination, entry))
    end
    %w[tmp log storage].each do |dir|
      FileUtils.mkdir_p(File.join(destination, dir))
    end
  end

  def omitted_app_env(root)
    {
      "RAILS_ENV" => "test",
      "PATH" => ENV["PATH"],
      "LANG" => ENV.fetch("LANG", "en_US.UTF-8"),
      "HOME" => ENV["HOME"],
      "BUNDLE_GEMFILE" => File.join(root, "Gemfile"),
      "PGHOST" => ENV["PGHOST"],
      "PGPORT" => ENV["PGPORT"],
      "PGUSER" => ENV["PGUSER"],
      "PGPASSWORD" => ENV["PGPASSWORD"],
      # Inherit CI/local connection settings (host, user, password) and only
      # swap the database name. A bare socket URL breaks GitHub Actions
      # where Postgres is reached over TCP via DATABASE_URL.
      "DATABASE_URL" => omit_database_url,
      "SECRET_KEY_BASE" => "0" * 64,
      "RAILS_MASTER_KEY" => master_key_for(root)
    }.compact
  end

  def omit_database_url
    base = ENV["DATABASE_URL"].to_s.strip
    if base.empty?
      "postgres:///vela_foundation_omit_test"
    else
      uri = URI.parse(base)
      uri.path = "/vela_foundation_omit_test"
      uri.to_s
    end
  end

  def prepare_omit_database!(env, root)
    create_out, create_err, create_status = Open3.capture3(
      env,
      RbConfig.ruby, File.join(root, "bin/rails"), "db:prepare",
      chdir: root
    )
    assert_predicate create_status, :success?, "db:prepare failed for omit suite:\n#{create_err}\n#{create_out}"
  end

  def master_key_for(root)
    key_path = File.join(root, "config/master.key")
    return File.read(key_path, encoding: "UTF-8").strip if File.file?(key_path)

    ENV["RAILS_MASTER_KEY"]
  end
end
