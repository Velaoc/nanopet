# Product surface

**Rule:** features only appear when they belong to the app being built.

Modules decide which code is on disk (`docs/MODULES.md`). The **product
surface** decides which foundation chrome a signed-in person is offered for
*this* product. Organizations, billing, OAuth connections, and operator
admin can exist underneath without showing up as primary navigation on a
simple shop or game.

## Configure

`config/foundation.yml`:

```yaml
product_surface: commerce   # platform | commerce | workspace | consumer
product_surface_features:   # optional boolean overrides
  billing: false
```

| Profile | Intent | Primary chrome |
|---|---|---|
| `platform` | Full foundation demo / unstamped template | Home or Shop, Organizations, Connections, Devices, Billing/CRM when present, Admin for operators |
| `commerce` | Digital storefront | Shop, Cart, Account (+ Admin for operators) |
| `workspace` | Team tools (CRM, SaaS) | Home, Organizations, Billing, Connections, Devices, CRM when present |
| `consumer` | Lightweight end-user product | Home, Account (+ Admin for operators) |

## API

```ruby
Foundation.product_surface.name          # => "commerce"
Foundation.surface_feature?(:organizations) # => false
Foundation.surface_feature?(:admin, operator: current_user.admin?)
```

Navigation is built only through `Foundation::NavigationHelper` —
do not hard-code foundation plumbing into product layouts.

## Pairing with design skins

When `design_skin` is left at the default pairing, surfaces pick a family:

| Surface | Default skin |
|---|---|
| platform | material |
| commerce | commerce |
| workspace | workspace |
| consumer | signal |

Override freely with `design_skin:` — see `docs/DESIGN_SKINS.md`.
