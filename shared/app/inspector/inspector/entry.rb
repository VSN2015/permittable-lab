module Inspector
  Entry = Struct.new(
    :request_id, :method, :path, :status, :raw_params, :permitted, :rejected, :violations,
    :response_body, :content_type, :log_lines, :events, :config,
    keyword_init: true
  ) do
    # A GET that never read permitted_params is page navigation, not a form post.
    def tracked?
      method.to_s != "GET" || !permitted.nil? || rejected == true
    end
  end
end
