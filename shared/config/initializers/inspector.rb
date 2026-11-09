if Inspector.enabled?
  Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, Inspector::Middleware

  ActiveSupport::Notifications.subscribe("invalid_parameters.permittable") do |*, payload|
    entry = Inspector::Current.entry
    entry.events << payload.slice(:controller, :action, :mode, :details).deep_dup if entry
  end

  Inspector::LogTap.attach
end
