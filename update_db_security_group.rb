require File.expand_path(File.dirname(__FILE__) + '/config')


(vpc_id, dbname) = ARGV
unless vpc_id && dbname
  puts "Usage: launch_instances <VPC_ID> <dbname>"
  exit 1
end

# Database needs to be in an available state to change the security group setting
rdsClient = AWS::RDS::Client::new
dbStatus = rdsClient.describe_db_instances({
    :db_instance_identifier => dbname
})[:db_instances].first[:db_instance_status]

if dbStatus != "available" then
  puts "database status must be available before updating security group (current status is '#{dbStatus}')"
  exit 1
end


ec2Client = AWS::EC2::Client::new


# Grab the private subnets. Note this assumes we know the subnets we
# are looking for via knowledge of how the VPC was created.
subnet_infos = ec2Client.describe_subnets({
  :filters => [
    {
      :name => "vpc-id",
      :values => [vpc_id]
    },
    {
      :name => "cidr",
      :values => ["10.0.1.0/24", "10.0.2.0/24"]
    }
  ]
})[:subnet_set]

subnet_ids = subnet_infos.map do |subnet|
  subnet[:subnet_id]
end

# Need the security group name
sg_infos = ec2Client.describe_security_groups({
    :filters => [
      {
          :name => "vpc-id",
          :values => [vpc_id]
      }
    ]
})[:security_group_info]

private_launch_sg = (sg_infos.select {
    |sg| sg[:group_name] == "sqlnet-sg"
  }).first[:group_id]






# Set the appropriate security group - note the API doesn't let us do this
# out of the box.

updated_sgs = rdsClient.modify_db_instance({
    :db_instance_identifier => dbname,
    :vpc_security_group_ids => [private_launch_sg]
})[:vpc_security_groups]

puts updated_sgs
