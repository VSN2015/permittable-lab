require "pp"

# Development/test side panel: shows how a request went through permittable.
# It only observes. Nothing here may change a response or call permitted_params.
module Inspector
  VALUE_LIMIT = 1_000
  BODY_LIMIT = 20_000
  LINE_LIMIT = 4_000

  module_function

  def enabled?(env = Rails.env)
    %w[development test].include?(env.to_s)
  end

  # Cut text for display: "<first limit chars>... (N more characters)".
  def clip(value, limit = VALUE_LIMIT)
    text = value.to_s
    return text if text.length <= limit

    "#{text[0, limit]}... (#{text.length - limit} more characters)"
  end
end
