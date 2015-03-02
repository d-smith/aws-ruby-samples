require 'aws-sdk'
require 'aws-sdk-v1'
require 'json'

config_file = File.join(File.dirname(__FILE__),
                        "../admin.json")
unless File.exist?(config_file)
  puts <<END
Put your credentials in an admin.json file (found one directory level up)

{"AccessKeyId":"access key id", "SecretAccessKey":"secret key id"}

END
  exit 1
end

creds = JSON.load(File.read('../admin.json'))
awsCreds = Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])

key = creds['AccessKeyId']
secret = creds['SecretAccessKey']

Aws.config[:credentials] = awsCreds
Aws.config[:region] = "us-east-1"
