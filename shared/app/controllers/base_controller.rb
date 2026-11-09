class BaseController < ActionController::Base
  include Permittable
  layout "lab"
end
