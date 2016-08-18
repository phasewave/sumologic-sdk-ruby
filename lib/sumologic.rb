require 'faraday'
require 'faraday_middleware'
require 'faraday-cookie_jar'
require 'multi_json'

module SumoLogic
  VERSION = '0.0.5'.freeze
  HOST = 'api.sumologic.com'.freeze
  APIVERSION = 'v1'.freeze
  PATH = 'api'.freeze

  # Sumologic API Client
  #
  # Supports search job API, dashboards API, and collectors API.
  #
  class Client
    attr_reader :endpoint

    def initialize(access_id = nil, access_key = nil, endpoint = nil, path = SumoLogic::PATH, version = SumoLogic::APIVERSION, host = SumoLogic::HOST)
      @endpoint = endpoint ? URI.parse(endpoint) : URI::HTTPS.build(host: host, path: "/#{path}/#{version}")
      @access_id = access_id
      @access_key = access_key

      reload_session
    end

    def search(query, from_time = nil, to_time = nil, time_zone = 'UTC')
      params = { q: query, from: from_time, to: to_time, tz: time_zone }
      r = @session.get do |req|
        req.url 'logs/search'
        req.params = params
      end
    end

    def search_job(query, from_time = nil, to_time = nil, time_zone = 'UTC')
      params = { query: query, from: from_time, to: to_time, timeZone: time_zone }
      url = 'search/jobs'
      post(url, params)
    end

    def search_job_status(search_job = {})
      url = 'search/jobs/' + search_job['id'].to_s
      get(url)
    end

    def search_job_records(search_job, limit = nil, offset = 0)
      params = { limit: limit, offset: offset }
      url = 'search/jobs/' + search_job['id'].to_s + '/records'
      get(url, params, 'records')
    end

    def dashboards(monitors = false)
      params = { dashboards: monitors }
      url = 'dashboards'
      get(url, params, url)
    end

    def collectors
      get('collectors')
    end

    def collector(collector_id)
      url = 'collectors/' + collector_id.to_s
      get(url, key: 'collector')
    end

    def collector_sources(collector_id)
      url = 'collectors/' + collector_id.to_s + '/sources'
      get(url, key: 'sources')
    end

    def collector_source(collector_id, source_id)
      url = 'collectors/' + collector_id.to_s + '/sources/' + source_id.to_s
      get(url, key: 'source')
    end

    def create_source(collector_id, params)
      url = 'collectors/' + collector_id.to_s + '/sources'
      post(url, MultiJson.encode(params), 'source')
    end

    def dashboard(dashboard_id)
      url = 'dashboards/' + dashboard_id.to_s
      get(url, key: 'dashboard')
    end

    def dashboard_data(dashboard_id)
      url = 'dashboards/' + dashboard_id.to_s + '/data'
      get(url, key: 'dashboardMonitorDatas')
    end

    private

    def get(url, body = nil, key = nil)
      r = nil
      loop do
        r = @session.get do |req|
          req.url url
          req.body = body
        end
        break if r.to_hash[:url].host == endpoint.host
        endpoint.host = r.to_hash[:url].host
        reload_session
      end

      return r.body.fetch(key, nil) if key
      r.body
    end

    def post(url, body, key = nil)
      r = nil
      loop do
        r = @session.post do |req|
          req.url url
          req.body = body
        end
        break if r.to_hash[:url].host == endpoint.host
        endpoint.host = r.to_hash[:url].host
        reload_session
      end

      return r.body.fetch(key, nil) if key
      r.body
    end

    def reload_session
      @session  = Faraday.new(url: endpoint.to_s) do |conn|
        conn.basic_auth(@access_id, @access_key)
        conn.use      FaradayMiddleware::FollowRedirects, limit: 5
        conn.use      :cookie_jar
        conn.request  :multipart
        conn.request  :json
        conn.response :json, content_type: 'application/json'
        conn.adapter  Faraday.default_adapter
      end
    end
  end
end
