class BaseController < ActionController::Base
  include Permittable
  layout "lab"

  prepend_around_action :switch_locale

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def switch_locale(&action)
    requested = params[:locale]
    locale = requested.is_a?(String) && I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
