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

    def initialize(access_id=nil, access_key=nil, endpoint=nil, path=SumoLogic::PATH, version=SumoLogic::APIVERSION, host=SumoLogic::HOST)
      @endpoint = endpoint ? URI.parse(endpoint) : URI::HTTPS.build(host: host, path: "/#{path}/#{version}")
      @access_id = access_id
      @access_key = access_key

      reload_session
    end

    def search(query, from_time=nil, to_time=nil, time_zone='UTC')
      params = {q: query, from: from_time, to: to_time, tz: time_zone}
      r = @session.get do |req|
        req.url 'logs/search'
        req.params = params
      end
    end

    def search_job(query, from_time=nil, to_time=nil, time_zone='UTC')
      params = {query: query, from: from_time, to: to_time, timeZone: time_zone}
      r = @session.post do |req|
        req.url 'search/jobs'
        req.body = MultiJson.encode(params)
      end
    end

    def search_job_status(search_job={})
      r = @session.get do |req|
        req.url 'search/jobs/' + search_job['id'].to_s
      end
    end

    def search_job_records(search_job, limit=nil, offset=0)
      params = {limit: limit, offset: offset}
      r = @session.get do |req|
        req.url 'search/jobs/' + search_job['id'].to_s + '/records'
        req.params = params
      end
    end

    def dashboards(monitors=false)
      params = {dashboards: monitors}
      r = @session.get do |req|
        req.url 'dashboards'
        req.params = params
      end
      return r.body.has_key?('dashboards') ? r.body['dashboards'] : nil
    end

    def collectors
      get('collectors')
    end

    def collector(collector_id)
      url = 'collectors/' + collector_id.to_s
      get(url, 'collector')
    end

    def collector_sources(collector_id)
      url = 'collectors/' + collector_id.to_s + '/sources'
      get(url, 'sources')
    end

    def collector_source(collector_id, source_id)
      url = 'collectors/' + collector_id.to_s + '/sources/' + source_id.to_s
      get(url, 'source')
    end

    def create_source(collector_id, params)
      url = 'collectors/' + collector_id.to_s + '/sources'
      post(url, MultiJson.encode(params), 'source')
    end

    def dashboard(dashboard_id)
      r = @session.get do |req|
        req.url 'dashboards/' + dashboard_id.to_s
      end
      return r.body.has_key?('dashboard') ? r.body['dashboard'] : nil
    end

    def dashboard_data(dashboard_id)
      r = @session.get do |req|
        req.url 'dashboards/' + dashboard_id.to_s + '/data'
      end
      return r.body.has_key?('dashboardMonitorDatas') ? r.body['dashboardMonitorDatas'] : nil
    end

    private

    def get(url, desired_output_key=nil)
      desired_output_key ||= url
      r = nil
      loop do
        r = @session.get do |req|
          req.url url
        end
        break if r.to_hash[:url].host == endpoint.host
        endpoint.host = r.to_hash[:url].host
        reload_session
      end

      return r.body.fetch(desired_output_key, nil) if desired_output_key
      r
    end

    def post(url, body, desired_output_key=nil)
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

      return r.body.fetch(desired_output_key, nil) if desired_output_key
      r
    end

    def reload_session
      headers   = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
      @session  = Faraday.new(url: endpoint.to_s, headers: headers) do |conn|
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
