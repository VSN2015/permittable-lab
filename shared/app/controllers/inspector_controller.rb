# The dev/test panel. Not a BaseController: it has no contract, no lab layout,
# and the middleware does not record it.
class InspectorController < ActionController::Base
  layout false
  around_action :switch_locale

  def show
    @entry = params[:entry].present? ? Inspector::Store.find(params[:entry].to_s) : Inspector::Store.latest
  end

  private

  def switch_locale(&action)
    requested = params[:locale].to_s
    locale = I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
