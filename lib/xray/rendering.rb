require "action_view/template"

module Xray
  module Rendering
    def render(*args, **kwargs, &block)
      path = identifier
      view = args.first
      source = super(*args, **kwargs, &block)
      return source unless source

      return source if view.respond_to?(:mailer) && view.mailer
      return source if path.include?('_xray_bar')
      return source if !(path =~ /\.(html|slim|haml|hamlc)(\.|$)/)
      return source if path =~ /\.(js|json|css)(\.|$)/

      options = args.last.kind_of?(Hash) ? args.last : {}
      return source if options.has_key?(:xray) && (options[:xray] == false)

      Xray.augment_template(source, path)
    end
  end
end

ActionView::Template.prepend Xray::Rendering
