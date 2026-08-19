Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Email/password authentication (SPEC M2). Custom controllers add the
  # Turnstile check and the legal-assent record on top of stock Devise.
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    passwords: "users/passwords",
    confirmations: "users/confirmations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Operator administration (SPEC M6). The authenticated route constraint
  # prevents the admin surface from matching for guests, normal users, or
  # organization admins. Controllers repeat the User#admin? authorization so
  # mounted engines and future route changes still fail closed independently.
  authenticated :user, ->(user) { user.admin? } do
    scope path: "admin", module: "madmin", as: "madmin" do
      get "dashboard", to: "dashboard#show", as: :root

      resources :users, only: %i[index show] do
        post :lock, on: :member
        post :unlock, on: :member
        post :revoke_all_sessions, on: :member
      end
      resources :organizations, only: %i[index show] do
        post :assign_plan, on: :member
        post :remove_plan, on: :member
      end
      resources :memberships, only: %i[index show]
      resources :invitations, only: %i[index show]
      resources :sessions, only: %i[index show] do
        post :revoke, on: :member
      end
      resources :events, only: %i[index show], path: "login-activity", controller: "session_events"
    end


    mount MissionControl::Jobs::Engine => "/admin/jobs", as: :admin_jobs
  end

  # Versioned legal documents (SPEC M2.4).
  get "legal/terms",   to: "foundation/legal#terms",   as: :legal_terms
  get "legal/privacy", to: "foundation/legal#privacy", as: :legal_privacy

  # Public tier comparison plus organization-scoped Stripe Checkout and
  # customer portal flows (SPEC M5). Pay mounts signed webhook endpoints at
  # /pay/webhooks/:provider separately.
  get  "pricing",          to: "foundation/pricing#show",  as: :pricing
  get  "billing",          to: "foundation/billing#show",  as: :billing
  post "billing/checkout", to: "foundation/billing#checkout", as: :billing_checkout
  post "billing/portal",   to: "foundation/billing#portal",   as: :billing_portal

  # Legal-assent interstitial for first-time OAuth users (SPEC M3.3):
  # shown before any account is created; DELETE declines and abandons it.
  get    "oauth/assent", to: "foundation/oauth_signups#new", as: :oauth_assent
  post   "oauth/assent", to: "foundation/oauth_signups#create"
  delete "oauth/assent", to: "foundation/oauth_signups#destroy"

  # Linked sign-in providers: explicit connect/disconnect (SPEC M3.3).
  get    "settings/connections",     to: "foundation/connections#show",    as: :settings_connections
  delete "settings/connections/:id", to: "foundation/connections#destroy", as: :settings_connection

  # Step-up reauthentication (sudo mode) before sensitive mutations.
  resource :reauthentication, only: %i[new create],
    controller: "foundation/reauthentications",
    path: "settings/reauthentication" do
    post "oauth/:provider", action: :oauth, as: :oauth, on: :collection
  end

  # End-user device sessions — live rows only (no login history in v1).
  scope path: "settings/sessions", as: :settings_sessions, module: "foundation" do
    get    "/",       to: "devices#index",   as: :root
    delete "/others", to: "devices#others",  as: :others
    delete "/:id",    to: "devices#destroy", as: :session
  end

  # Organization invitation emails carry a signed, expiring token
  # (SPEC M4.2); redeeming it lands on the public acceptance page. Declared
  # before the engine mount so it wins over the engine's GET
  # /invitations/:token.
  get "invitations/mail/:signed_token",
    to: "foundation/invitation_links#show", as: :organization_invitation_link



  # Team workspaces: organizations, members, switching, and invitations
  # (SPEC M4) — the organizations gem's engine, mounted at the root. All
  # application-owned paths stay above this catch-all mount.
  mount Organizations::Engine => "/"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Deeper operational healthcheck (database, migrations, queue, storage);
  # checks are defined in config/allgood.rb.
  mount Allgood::Engine => "/healthcheck"

  # Web application manifest, rendered from config/foundation.yml (SPEC
  # M10.2) and linked from the layouts. No service worker is registered: the
  # foundation ships no offline cache, so nothing here can serve stale
  # authenticated pages.
  get "manifest.webmanifest", to: "foundation/pwa#manifest", as: :pwa_manifest, format: false

  # Native mobile shell server contract (SPEC M14). Association files are
  # public (OS verifiers). Path configuration, entry, auth, and session poll
  # are gated on native-shell detection inside the controllers.
  get ".well-known/apple-app-site-association",
    to: "foundation/native/associations#apple",
    as: :apple_app_site_association,
    format: false
  get "apple-app-site-association",
    to: "foundation/native/associations#apple",
    format: false
  get ".well-known/assetlinks.json",
    to: "foundation/native/associations#android",
    as: :android_assetlinks,
    format: false

  scope path: "native", module: "foundation/native", as: :native do
    get "configurations/:platform/v:version",
      to: "path_configurations#show",
      constraints: { platform: /ios|android/, version: /\d+/ },
      as: :path_configuration,
      format: false
    get "entry", to: "entries#show", as: :entry
    get "auth", to: "auth#show", as: :auth
    get "session", to: "sessions#show", as: :session
  end

  # Minimal landing page until the M7 marketing set replaces it.
    root "foundation/home#show"
end
