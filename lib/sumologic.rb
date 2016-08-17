require 'tempfile'
require 'faraday'
require 'faraday_middleware'
require 'faraday-cookie_jar'
require 'multi_json'

module SumoLogic
  VERSION = '0.0.5'
  URL = 'https://api.sumologic.com/api/v1'

  class Client

    def initialize(access_id=nil, access_key=nil, endpoint=SumoLogic::URL)
      @endpoint = endpoint
      @session  = Faraday
      headers   = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
      @session  = Faraday.new(url: @endpoint, headers: headers) do |conn|
        conn.basic_auth(access_id, access_key)
        conn.use      FaradayMiddleware::FollowRedirects, limit: 5
        conn.use      :cookie_jar
        conn.request  :multipart
        conn.request  :json
        conn.response :json, content_type: 'application/json'
        conn.adapter  Faraday.default_adapter
      end
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
      r = @session.get do |req|
        req.url 'collectors'
      end
      return r.body.has_key?('collectors') ? r.body['collectors'] : nil
    end

    def collector(collector_id)
      r = @session.get do |req|
        req.url 'collectors/' + collector_id.to_s
      end
      return r.body.has_key?('collector') ? r.body['collector'] : nil
    end

    def collector_sources(collector_id)
      r = @session.get do |req|
        req.url 'collectors/' + collector_id.to_s + '/sources'
      end
      return r.body.has_key?('sources') ? r.body['sources'] : nil
    end

    def create_collector(name, type='HTTP', message_per_request=false)
      Tempfile.open('sumo_create_collector') do |file|
        file.write({source: {name: name, sourceType: type, messagePerRequest: message_per_request}}.to_json)
        file.close
        payload = Faraday::UploadIO.new(file.path, 'application/json')
        binding.pry
        r = @session.post do |req|
          req.url 'collectors'
          req.body = payload
        end
        binding.pry
      end
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

  end
end
