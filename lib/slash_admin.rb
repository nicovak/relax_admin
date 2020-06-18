# frozen_string_literal: true

require "slash_admin/engine"
require "cancancan"
require "pagy"
require "groupdate"
require "ruby_identicon"
require "bcrypt"
require "chartkick"
require "chart-js-rails"
require "highcharts-rails"
require "js-routes"
require "i18n-js"
require "bootstrap"
require "cocoon"
require "datetime_picker_rails"
require "jquery-rails"
require "jquery-minicolors-rails"
require "momentjs-rails"
require "tether-rails"
require "sweetalert-rails"
require "http_accept_language"
require "batch_translation"

module SlashAdmin
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :available_locales

    def initialize
      @available_locales = I18n.available_locales
    end
  end
end
