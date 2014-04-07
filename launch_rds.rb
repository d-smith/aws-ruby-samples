require File.expand_path(File.dirname(__FILE__) + '/config')


(vpc_id, dummyarg) = ARGV
unless vpc_id
  puts "Usage: launch_instances <VPC_ID>"
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


# Create an RDS subnet group containing the two private subnets
rdsClient = AWS::RDS::Client::new

db_subnet_group = rdsClient.create_db_subnet_group({
    :db_subnet_group_name => "vpc-db-subnet-group",
    :db_subnet_group_description => "VPC DB Subnet Group",
    :subnet_ids => subnet_ids
})
