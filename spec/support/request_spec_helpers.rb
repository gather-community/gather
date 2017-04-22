module RequestSpecHelpers
  def with_subdomain(subdomain)
    apex = Settings.url.host
    host!("#{subdomain}.#{apex}")
    yield
    host!(apex)
  end
end
