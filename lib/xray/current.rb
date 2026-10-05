require "active_support/current_attributes"

module Xray
  # Holds what the Xray bar shows about the current request. Rails resets it
  # around every request and job, so a thread or fiber picking up the next one
  # never shows the controller and view of the last.
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_info, default: -> { {} }
  end
end
