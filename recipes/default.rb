#
# Cookbook:: snipe_audit
# Recipe:: default
#
# MIT
#

# Install required libs
chef_gem 'httparty' do
  version '0.16.2'
  compile_time true
  action :install
end
chef_gem 'wmi-lite' do
  version '1.0'
  compile_time true
  action :install
end
require 'httparty'
require 'wmi-lite'

# Our functions
def get_asset_by_serial(base_url, headers, serial)
  HTTParty.get(
      "#{base_url}/hardware/byserial/#{serial}",
      :headers => headers,
      :verify => false
  )
end

def get_asset_models(base_url, headers)
  HTTParty.get("#{base_url}/models?limit=500&sort=id&order=asc",
               :headers => headers,
               :verify => false
  )
end

def post_asset(base_url, headers, data)
  HTTParty.post(
      "#{base_url}/hardware",
      :headers => headers,
      :body => data.to_json,
      :verify => false
  )
end

def patch_asset(base_url, headers, data, id)
  HTTParty.patch(
      "#{base_url}/hardware/#{id}",
      :headers => headers,
      :body => data.to_json,
      :verify => false
  )
end

def get_model_id_from_model_number(models, model_name)
  models.each do |model|
    if model['model_number'].to_s == model_name.to_s
      return model['id']
    end
  end
  return nil
end

def build_base_url(hostname, port, use_https)
  if hostname.to_s.empty? or port.to_s.empty?
    return false
  end
  use_https ? "https://#{hostname}:#{port.to_s}/api/v1" : "http://#{hostname}:#{port.to_s}/api/v1"
end

# Make sure we are on Windows
if node['platform_family'].to_s.downcase === 'windows' and RUBY_PLATFORM =~ /mswin|mingw32|windows/

  # Store Snipe info in vars for later
  base_url = build_base_url(node['snipe']['server']['host_name'], node['snipe']['server']['port'], node['snipe']['server']['use_https'])
  token = node['snipe']['user']['api_token']
  os_name_field = node['snipe']['fields']['os']['name']
  os_version_field = node['snipe']['fields']['os']['version']
  headers = {
      "Authorization" => "Bearer " + token,
      "Accept" => "application/json",
      "Content-Type" => "application/json"
  }.to_h

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
    models_response = get_asset_models(base_url, headers)
    this_asset_response = get_asset_by_serial(base_url, headers, serial)

    # Make sure that there is a list of models to pick from
    if models_response['total'].to_i > 0
      # Make sure that there is at most 1 asset to choose from based on the serial
      if this_asset_response['total'].to_i <= 1

        # Parse the bodies returned from Snipe
        models = models_response['rows']
        this_asset = this_asset_response['total'].to_i.equal?(1) ? this_asset_response['rows'][0] : nil

        # Determine the Snipe model id based on the detected model string
        model_id = get_model_id_from_model_number(models, model_number)

        # Were we able to get the model id?
        if !model_id.nil?

        # Build the asset data obj
        asset = {
            :serial => serial,
            :name => hostname,
            :model_id => model_id
        }
        if os_name_field
          asset[os_name_field.to_s] = os
        end
        if os_version_field
          asset[os_version_field.to_s] = os_ver
        end

        # If the asset does not already exist in Snipe
        if this_asset.nil?
          # Post a new asset
          response = post_asset(base_url, headers, asset)
        else
          # Update the asset
          response = patch_asset(base_url, headers, asset, this_asset['id'])
        end

        # Log the status and response from Snipe
        if response['status'].to_s.eql?('error')
          response['messages'].each do |message|
            message.each_with_index {|key, value|
              log 'Snipe Audit' do
                message "#{key}: #{value}"
                level :error
              end}
          end
        elsif response['status'].to_s.eql?('success')
          log 'Snipe Audit' do
            message response['messages'].to_s
            level :info
          end
        else
          log 'Snipe Audit' do
            message "Status: #{response['status'].to_s}"
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
      message "Found no models in Snipe. #{models_response.to_s}"
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
