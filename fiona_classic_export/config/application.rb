require File.expand_path('../boot', __FILE__)

require "rails"
require "active_model/railtie"
require "active_record/railtie"

Bundler.require(*Rails.groups)

module FionaExportApp
  class Application < Rails::Application
  end
end

# Dummy to satisfy Fiona and Rails Connector Gem dependencies.
class ApplicationController
  def self.helper_method(*args)
  end

  def self.helper(*args)
  end
end
