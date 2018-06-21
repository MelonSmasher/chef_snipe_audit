#
# Cookbook:: snipe_audit
# Recipe:: default
#
# MIT
#

# Install required libs
chef_gem 'http' do
  version '3.3'
  compile_time true
  action :install
end
chef_gem 'wmi-lite' do
  version '1.0'
  compile_time true
  action :install
end
require 'wmi-lite'

# Our functions
def get_asset_by_serial(base_url, token, serial)
  require 'http'
  HTTP[:accept => "application/json"]
      .auth("Bearer #{token}")
      .get("#{base_url}/hardware/byserial/#{serial}")
end

def get_asset_models(base_url, token)
  require 'http'
  HTTP[:accept => "application/json"]
      .auth("Bearer #{token}")
      .get("#{base_url}/models?limit=500&sort=id&order=asc")
end

def post_asset(base_url, token, data)
  require 'http'
  HTTP["Content-Type" => "application/json"]
      .auth("Bearer #{token}")
      .patch("#{base_url}/hardware", :json => data)
end

def patch_asset(base_url, token, data, id)
  require 'http'
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

# Make sure we are on Windows
if node['platform_family'].to_s.downcase === 'windows' and RUBY_PLATFORM =~ /mswin|mingw32|windows/

  # Store Snipe info in vars for later
  base_url = build_base_url(node['snipe']['host_name'], node['snipe']['port'], node['snipe']['use_https'])
  token = node['snipe']['user']['api_token']
  os_name_field = node['snipe']['fields']['os']['name']
  os_version_field = node['snipe']['fields']['os']['version']

  # Ensure we have some basic information
  if base_url and !token.empty?

    # Make a new WMI interface
    wmi = WmiLite::Wmi.new

    # Get info about this machine from this machine
    os = 'Windows'
    os_ver = node['os_version']
    hostname = node['machinename'].to_s.upcase
    serial = wmi.first_of('Win32_Bios')['serialnumber'].to_s.upcase
    model_number = wmi.first_of('Win32_ComputerSystem')['model'].to_s

    # Get info from Snipe
    models_response = get_asset_models(base_url, token)
    this_asset_response = get_asset_by_serial(base_url, token, serial)

    # Make sure that there is a list of models to pick from
    if models_response.body['total'] > 0
      # Make sure that there is at most 1 asset to choose from based on the serial
      if this_asset_response.body['total'] <= 1

        # Parse the bodies returned from Snipe
        models = models_response.body['rows']
        this_asset = this_asset_response.body['total'].equal?(1) ? this_asset_response.body['rows'][0] : nil

        # Determine the Snipe model id based on the detected model string
        model_id = get_model_id_from_model_number(models, model_number)

        # Were we able to get the model id?
        if !model_id.nil?

          # Build the asset data obj
          asset = [
              :serial => serial,
              :name => hostname,
              :model_id => model_id
          ]
          if os_name_field
            asset[os_name_field.to_s.to_sym => os]
          end
          if os_version_field
            asset[os_version_field.to_s.to_sym => os_ver]
          end

          # If the asset does not already exist in Snipe
          if this_asset.nil?
            # Post a new asset
            response = post_asset(base_url, token, asset)
          else
            # Update the asset
            response = patch_asset(base_url, token, asset, this_asset['id'])
          end

          # Log the status and response from Snipe
          if response.body['status'].to_s.eql?('error')
            response.body['messages'].each do |message|
              message.each_with_index {|key, value|
                log 'Snipe Audit' do
                  message "#{key}: #{value}"
                  level :error
                end}
            end
          elsif response.body['status'].to_s.eql?('success')
            log 'Snipe Audit' do
              message response.body['messages'].to_s
              level :info
            end
          else
            log 'Snipe Audit' do
              message "Status: #{response.body['status'].to_s}"
              level :warn
            end
          end

        else
          log 'Snipe Audit' do
            message "Unable to match this model: #{model_number} to one in Snipe."
            level :warn
          end
        end
      else
        log 'Snipe Audit' do
          message "Found more than one asset in Snipe with this serial number: #{serial} ensure that all serial numbers are unique!"
          level :warn
        end
      end
    else
      log 'Snipe Audit' do
        message "Found no models in Snipe."
        level :warn
      end
    end
  else
    log 'Snipe Audit' do
      message "The snipe server is not configured in Chef."
      level :warn
    end
  end
else
  log 'Snipe Audit' do
    message "The platform family: #{node['platform_family']} is not supported at this time."
    level :warn
  end
end
