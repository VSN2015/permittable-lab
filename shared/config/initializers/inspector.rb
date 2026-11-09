if Inspector.enabled?
  Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, Inspector::Middleware

  ActiveSupport::Notifications.subscribe("invalid_parameters.permittable") do |*, payload|
    begin
      entry = Inspector::Current.entry
      entry.events << payload.slice(:controller, :action, :mode, :details).deep_dup if entry
    rescue StandardError
      nil
    end
  end

  Inspector::LogTap.attach
end
