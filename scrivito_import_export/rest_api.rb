require 'addressable/uri'
require 'net/http'
require 'net/http/post/multipart'
require 'openssl'

class RestApi
  class ScrivitoError < StandardError; end

  def initialize(base_url, tenant, api_key)
    @base_url = base_url
    @tenant = tenant
    @api_key = api_key
  end

  def get(path, payload = nil)
    request_cms_api(Net::HTTP::Get, path, payload)
  end

  def put(path, payload)
    request_cms_api(Net::HTTP::Put, path, payload)
  end

  def post(path, payload)
    request_cms_api(Net::HTTP::Post, path, payload)
  end

  def delete(path, payload = nil)
    request_cms_api(Net::HTTP::Delete, path, payload)
  end

  def upload_future_binary(file_to_upload, filename, obj_id, content_type: nil)
    permission = get('blobs/upload_permission')
    upload = upload_file(file_to_upload, nil, permission)
    put('blobs/activate_upload',
        filename: filename, content_type: content_type, upload: upload, obj_id: obj_id)
  end

  def normalize_path_component(s)
    Addressable::URI.normalize_component(s, Addressable::URI::CharacterClasses::UNRESERVED)
  end

  private

  def request_cms_api(method, path, payload)
    response = response_for_request_cms_api(method, path, payload)
    if response.is_a?(Hash) && response.keys == ['task'] && response['task'].is_a?(Hash)
      task_path = "tasks/#{response['task']['id']}"
      begin
        sleep(2 + rand)
        task_data = response_for_request_cms_api(Net::HTTP::Get, task_path, nil)
      end until task_data['status'] != 'open'
      if task_data['status'] == 'success'
        task_data['result']
      else
        raise ScrivitoError, "412 #{task_data['code']} #{task_data['message']}"
      end
    else
      response
    end
  end

  def response_for_request_cms_api(method, path, payload)
    req = method.new(URI.parse("#{@base_url}/tenants/#{@tenant}/#{path}"))
    req.basic_auth('api_token', @api_key)
    req['Content-type'] = 'application/json'
    req['Accept'] = 'application/json'
    req['Scrivito-Priority'] = 'background'
    req.body = JSON.dump(payload) if payload.present?
    response = retry_on_rate_limit(Time.now + 25.seconds) do
      perform_request(req)
    end
    if response.code.start_with?('2')
      JSON.load(response.body)
    else
      raise ScrivitoError, "#{response.code} #{response.body}"
    end
  end

  def retry_on_rate_limit(timeout, &block)
    internal_retry(block, timeout, 1)
  end

  def internal_retry(request_proc, timeout, backoff_wait_time)
    response = request_proc.call
    if response.code == '429'
      if Time.now < timeout
        sleep_time = [backoff_wait_time, response['Retry-After'].to_f].max
        sleep(sleep_time)
        internal_retry(request_proc, timeout, 2 * backoff_wait_time)
      else
        raise ScrivitoError, '429 rate limit exceeded'
      end
    else
      response
    end
  end

  def perform_request(req)
    uri = req.uri
    conn = Net::HTTP.new(uri.host, uri.port)
    conn.use_ssl = true
    conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
    conn.cert_store = OpenSSL::X509::Store.new.tap do |store|
      store.set_default_paths
      # store.add_file("config/ca-bundle.crt")
    end
    conn.open_timeout = 10
    conn.read_timeout = 30
    conn.ssl_timeout = 10
    conn.request(req)
  end

  def upload_file(file, content_type, upload_permission)
    File.open(file) do |open_file|
      upload_io = UploadIO.new(open_file, content_type, File.basename(file))
      params = upload_permission['fields'].merge('file' => upload_io)
      uri = URI.parse(upload_permission['url'])
      uri.normalize!
      req = Net::HTTP::Post::Multipart.new(uri, params)
      response = perform_request(req)
      if response.code.starts_with?('2')
        upload_permission['blob']
      else
        raise ScrivitoError, "File upload failed with code #{response.code}"
      end
    end
  end
end
