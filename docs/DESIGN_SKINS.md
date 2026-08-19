# Design skins

**Rule:** a generated app should look like the product it is — not a generic
admin shell with a different logo.

Design skins are **conceptual visual families** layered on Material Design 3
tokens. They remap shell colors, top bar, navigation active states, cards,
and primary buttons. They do **not** replace MD3 components or invent a
second component library.

## Configure

```yaml
design_skin: commerce   # material | commerce | workspace | arcade | vault | signal
```

If omitted, the skin pairs from `product_surface` (see PRODUCT_SURFACE.md).

| Skin | Concept | Typical products |
|---|---|---|
| `material` | Stock MD3 from `brand_seed_color` | Unstamped template, light SaaS |
| `commerce` | Dark precision storefront — grid wash, glass panels, luminous CTAs | Digital shops, license stores |
| `workspace` | Ops console — dense navy deck, cyan signals, mono labels | CRM, internal tools |
| `arcade` | Entertainment HUD — void, neon edges, telemetry type | Games, live events |
| `vault` | Holdings terminal — charcoal, bullion marks, tabular finance | Portfolios, TCG trackers |
| `signal` | Messaging OS — cool slate, teal accents, soft geometry | Chat, support, inbox |

## How it works

1. `Foundation::DesignSkin.resolve` reads `config/foundation.yml`.
2. The application layout adds `design-skin--{name}` on `<body>`.
3. `app/assets/stylesheets/design_skins.css` overrides MD3 CSS variables
   and a small set of shell selectors.
4. Product views keep using MD3 partials (`.md-button`, `.md-card`, …).

```erb
<body class="md-app <%= foundation_design_skin_body_class %>"
      data-design-skin="<%= Foundation.design_skin.name %>"
      data-product-surface="<%= Foundation.product_surface.name %>">
```

## Authoring a product-specific look

1. Pick the closest family skin for 80% of chrome.
2. Add app-local CSS for unique heroes, boards, or canvases.
3. Keep tokens in CSS variables — never scatter raw hex in ERB.
4. Respect `prefers-reduced-motion` and contrast on accent fills.

## TCG / portfolio apps

Use `design_skin: vault` (or `consumer` surface + vault skin) and enable
`rarebox_data` for live marks — see `docs/RAREBOX_DATA.md`.
