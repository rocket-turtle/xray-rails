class ApplicationController < ActionController::Base
  protect_from_forgery

  if respond_to?(:content_security_policy) # Rails >= 5.2
    content_security_policy only: :strict_csp do |policy|
      policy.script_src :self, :strict_dynamic
      # Lists no source the app serves from, so only the nonce lets xray.css
      # in, and inline style attributes are refused.
      policy.style_src 'https://styles.invalid'
    end
  end

  def root
  end

  def strict_csp
    render :root
  end

  # For the tests
  def non_html
    render json: {foo: 'bar'}
  end
end
