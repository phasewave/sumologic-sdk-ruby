#!/usr/bin/env ruby
# This example uses a json elb template, you can erb to fill with the
# appropriate values and creates a sumo souce on a hosted collector
# which picks up elb logs from an s3 bucket.

require 'sumologic'
require 'erb'
require 'json'

sumo_id = ""
sumo_secret = ""
aws_sumo_id = ""
aws_sumo_secret = ""
collector_name = "" # Hosted collector name
application_env = "dev"
application = "web"
bucket_name = ""
bucket_path = "*/elasticloadbalancing/*"

sumo_elb_template = %Q(
{
  "source": {
    "name": "<%= application_env %>-<%= application %>",
    "description": "<%= application_env %>-<%= application %> elb logs",
    "category": "elb/<%= application_env %>/<%= application %>",
    "automaticDateParsing": true,
    "multilineProcessingEnabled": true,
    "useAutolineMatching": true,
    "contentType": "AwsElbBucket",
    "forceTimeZone": false,
    "filters": [],
    "encoding": "UTF-8",
    "thirdPartyRef": {
      "resources": [
        {
          "serviceType": "AwsElbBucket",
          "path": {
            "type": "S3BucketPathExpression",
            "bucketName": "<%= bucket_name %>",
            "pathExpression": "<%= bucket_path %>"
          },
          "authentication": {
            "type": "S3BucketAuthentication",
            "awsId": "<%= aws_sumo_id %>",
            "awsKey": "<%= aws_sumo_secret %>"
          }
        }
      ]
    },
    "scanInterval": 300000,
    "paused": false,
    "sourceType": "Polling",
    "alive": true
  }
}
)


sumo_source_json = ERB.new(sumo_elb_template, nil, "%").result(binding)

sumo_source_hash = JSON.parse(sumo_source_json)

sumo = SumoLogic::Client.new(sumo_id, sumo_secret)

# Get Collector id by name
collectors = sumo.collectors
collectors.map { |h| h['id'] }
collector_id = collectors.select { |h| h['name'] == collector_name }.first['id']

# Create the elb source
sumo.create_source(collector_id, sumo_source_hash)
