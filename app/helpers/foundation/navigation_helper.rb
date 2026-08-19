# frozen_string_literal: true

module Foundation
  # Builds primary navigation from the configured product surface so chrome
  # matches the app being built (docs/PRODUCT_SURFACE.md).
  module NavigationHelper
    def foundation_primary_nav_items(user:)
      items = []
      surface = Foundation.product_surface
      operator = user&.admin? == true


      # When storefront is omitted the shop/cart block above is stripped; keep
      # a plain home entry for surfaces that still want one.
      if !surface.feature?(:shop) && surface.feature?(:home) && items.none? { |item| item[:label] == "Home" || item[:label] == "Shop" }
        items << {
          label: "Home",
          icon: :home,
          href: root_path,
          active: request.path == root_path
        }
      end

      if surface.feature?(:organizations)
        items << {
          label: "Organizations",
          icon: :workspaces,
          href: organizations.organizations_path,
          active: request.path.start_with?("/organizations")
        }
      end

      if surface.feature?(:billing)
        items << {
          label: "Billing",
          icon: :payments,
          href: billing_path,
          active: request.path.start_with?("/billing") || request.path == pricing_path
        }
      end

      if surface.feature?(:connections)
        items << {
          label: "Connections",
          icon: :settings,
          href: settings_connections_path,
          active: request.path == settings_connections_path ||
            request.path.start_with?("/settings/connections")
        }
      end

      if surface.feature?(:devices)
        items << {
          label: "Devices",
          icon: :person,
          href: settings_sessions_root_path,
          active: request.path.start_with?("/settings/sessions") ||
            request.path.start_with?("/settings/reauthentication")
        }
      end

      if surface.feature?(:account)
        items << {
          label: "Account",
          icon: :person,
          href: settings_sessions_root_path,
          active: request.path.start_with?("/settings")
        }
      end


      if surface.feature?(:admin, operator: operator)
        items << {
          label: "Admin",
          icon: :task_alt,
          href: madmin_root_path,
          active: request.path.start_with?("/admin")
        }
      end

      items
    end

    def foundation_public_footer_links
      links = []
      surface = Foundation.product_surface


      if links.empty? && (surface.feature?(:pricing) || surface.feature?(:billing))
        links << { label: "Pricing", href: pricing_path }
      end

      links
    end

    def foundation_design_skin_body_class
      Foundation.design_skin.body_class
    end
  end
end
