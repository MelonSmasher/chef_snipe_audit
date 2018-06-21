chef_gem 'http' do
  version '3.3'
  compile_time true
  action :install
end

require 'http'

def get_asset_by_serial(base_url, token, serial)
  HTTP[:accept => "application/json"]
      .auth("Bearer #{token}")
      .get("#{base_url}/hardware/byserial/#{serial}")
end

def get_asset_models(base_url, token)
  HTTP[:accept => "application/json"]
      .auth("Bearer #{token}")
      .get("#{base_url}/models?limit=500&sort=id&order=asc")
end

def post_asset(base_url, token, data)
  HTTP["Content-Type" => "application/json"]
      .auth("Bearer #{token}")
      .patch("#{base_url}/hardware", :json => data)
end

def patch_asset(base_url, token, data, id)
  HTTP["Content-Type" => "application/json"]
      .auth("Bearer #{token}")
      .patch("#{base_url}/hardware/#{id}", :json => data)
end

def get_model_id_from_model_number(models, model_name)
  models.each do |model|
    if model['model_number'].equal?(model_name)
      return model['id']
    end
  end
  return nil
end

def build_base_url(hostname, port, use_https)
  if hostname.to_s.empty? or port.to_s.empty?
    return false
  end
  use_https ? "https://#{hostname}:#{port.to_s}" : "http://#{hostname}:#{port.to_s}"
end

