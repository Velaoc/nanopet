module Foundation
  module MaterialHelper
    MATERIAL_SYMBOLS = {
      "account_circle" => 0xF20B, "add" => 0xE145, "add_circle" => 0xE990,
      "analytics" => 0xEF3E, "arrow_back" => 0xE5C4, "arrow_forward" => 0xE5C8,
      "article" => 0xEF87, "attach_file" => 0xE226, "attach_money" => 0xE227,
      "bar_chart" => 0xE26B, "business" => 0xE7EE, "calendar_today" => 0xE935,
      "cancel" => 0xE888, "chat" => 0xE0C9, "check" => 0xE668,
      "check_circle" => 0xF0BE, "checklist" => 0xE6B1, "chevron_left" => 0xE5CB,
      "chevron_right" => 0xE5CC, "close" => 0xE5CD, "cloud_upload" => 0xE2C3,
      "content_copy" => 0xE14D, "credit_card" => 0xE8A1, "dark_mode" => 0xE51C,
      "dashboard" => 0xE871, "delete" => 0xE92E, "description" => 0xE873,
      "download" => 0xF090, "edit" => 0xF097, "error" => 0xF8B6,
      "event" => 0xE878, "expand_more" => 0xE5CF, "filter_list" => 0xE152,
      "folder" => 0xE2C7, "group" => 0xEA21, "help" => 0xE8FD,
      "history" => 0xE8B3, "home" => 0xE9B2, "image" => 0xE3F4,
      "info" => 0xE88E, "inventory_2" => 0xE1A1, "light_mode" => 0xE518,
      "link" => 0xE250, "list" => 0xE896, "local_shipping" => 0xE558,
      "lock" => 0xE899, "logout" => 0xE9BA, "mail" => 0xE159,
      "menu" => 0xE5D2, "more_horiz" => 0xE5D3, "more_vert" => 0xE5D4,
      "note_add" => 0xE89C, "notifications" => 0xE7F5, "open_in_new" => 0xE89E,
      "payments" => 0xEF63, "person" => 0xF0D3, "person_add" => 0xEA4D,
      "phone" => 0xF0D4, "print" => 0xE8AD, "receipt_long" => 0xEF6E,
      "refresh" => 0xE5D5, "remove" => 0xE15B, "save" => 0xE161,
      "schedule" => 0xEFD6, "search" => 0xEF7A, "send" => 0xE163,
      "settings" => 0xE8B8, "share" => 0xE80D, "shopping_cart" => 0xE8CC,
      "star" => 0xF09A, "store" => 0xE8D1, "support_agent" => 0xF0E2,
      "sync" => 0xE627, "tag" => 0xE9EF, "task_alt" => 0xE2E6,
      "trending_up" => 0xE8E5, "upload" => 0xF09B, "verified" => 0xEF76,
      "visibility" => 0xE8F4, "visibility_off" => 0xE8F5, "warning" => 0xF083,
      "workspaces" => 0xEA0F
    }.freeze

    BUTTON_VARIANTS = %i[filled tonal outlined text elevated].freeze
    CARD_VARIANTS = %i[elevated filled outlined].freeze
    CHOICE_TYPES = %i[checkbox radio switch].freeze
    SYMBOL_SIZES = [ 20, 24, 28, 32, 40, 48 ].freeze

    def material_symbol(name, size: 24, fill: false, label: nil, **attributes)
      glyph = name.to_s
      codepoint = MATERIAL_SYMBOLS[glyph]
      unless codepoint
        raise ArgumentError,
          "unknown Material Symbol: #{glyph}. Add the name and codepoint to " \
          "tools/material/symbols.txt and Foundation::MaterialHelper::MATERIAL_SYMBOLS, " \
          "then run tools/material/generate_symbols.sh (see docs/MATERIAL_DESIGN_3.md)."
      end

      pixel_size = Integer(size)
      raise ArgumentError, "unsupported symbol size: #{pixel_size}" unless SYMBOL_SIZES.include?(pixel_size)

      css_class = class_names("material-symbol", "material-symbol--#{pixel_size}", attributes.delete(:class), filled: fill)
      accessibility = label.present? ? { role: "img", aria: { label: label } } : { aria: { hidden: true } }

      tag.span(codepoint.chr(Encoding::UTF_8),
        **attributes,
        **accessibility,
        class: css_class)
    end

    def md_button(label = nil, href: nil, variant: :filled, icon: nil, loading: false, disabled: false, **attributes)
      variant = variant.to_sym
      raise ArgumentError, "unknown button variant: #{variant}" unless BUTTON_VARIANTS.include?(variant)

      render "foundation/components/button",
        label: label,
        href: href,
        variant: variant,
        icon: icon,
        loading: loading,
        disabled: disabled,
        attributes: attributes
    end

    def md_icon_button(icon, label:, selected: false, disabled: false, **attributes)
      render "foundation/components/icon_button",
        icon: icon, label: label, selected: selected, disabled: disabled, attributes: attributes
    end

    def md_text_field(form, attribute, label:, hint: nil, type: :text, **options)
      render "foundation/components/text_field",
        form: form, attribute: attribute, label: label, hint: hint, type: type, options: options
    end

    def md_select(form, attribute, choices, label:, hint: nil, **options)
      render "foundation/components/select",
        form: form, attribute: attribute, choices: choices, label: label, hint: hint, options: options
    end

    def md_choice(form, attribute, label:, type: :checkbox, value: "1", **options)
      type = type.to_sym
      raise ArgumentError, "unknown choice type: #{type}" unless CHOICE_TYPES.include?(type)

      render "foundation/components/choice",
        form: form, attribute: attribute, label: label, type: type, value: value, options: options
    end

    def md_card(variant: :elevated, **attributes, &block)
      variant = variant.to_sym
      raise ArgumentError, "unknown card variant: #{variant}" unless CARD_VARIANTS.include?(variant)

      render "foundation/components/card", variant: variant, attributes: attributes, content: capture(&block)
    end

    def md_chip(label, selected: false, removable: false, **attributes)
      render "foundation/components/chip",
        label: label, selected: selected, removable: removable, attributes: attributes
    end

    def md_progress(label: "Loading", value: nil)
      render "foundation/components/progress", label: label, value: value
    end

    def md_dialog(id:, title:, trigger_label:, actions: nil, &block)
      render "foundation/components/dialog",
        id: id, title: title, trigger_label: trigger_label, actions: actions, content: capture(&block)
    end

    def md_tooltip(label, text, **attributes)
      render "foundation/components/tooltip", label: label, text: text, attributes: attributes
    end
  end
end
