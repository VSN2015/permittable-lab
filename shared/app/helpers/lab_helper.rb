module LabHelper
  def lab_gem_label
    "#{Lab::GemSource.current.label(Permittable::VERSION)}, Rails #{Rails.version}"
  end
end
