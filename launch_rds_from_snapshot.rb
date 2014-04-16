require File.expand_path(File.dirname(__FILE__) + '/config')


(vpc_id, dbname, snapshot_id) = ARGV
unless vpc_id && dbname && snapshot_id
  puts "Usage: launch_instances <VPC_ID> <dbname> <snapshot_id>"
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


# Create an RDS subnet group containing the two private subnets
rdsClient = AWS::RDS::Client::new

db_subnet_group_name = dbname + "-subnet-group"

db_subnet_group = rdsClient.create_db_subnet_group({
    :db_subnet_group_name => db_subnet_group_name,
    :db_subnet_group_description => "VPC DB Subnet Group II",
    :subnet_ids => subnet_ids
})



# Create an RDS instance in the VPC
rdsCreateDB = rdsClient.restore_db_instance_from_db_snapshot({
    :db_snapshot_identifier => snapshot_id,
    :db_instance_identifier => dbname,
    :db_instance_class => "db.t1.micro",
#    :allocated_storage => 10,
#    :engine => "oracle-se",
#    :master_username => "fred",
#    :master_user_password => "fredpasword",
#    :vpc_security_group_ids => [private_launch_sg],
    :db_subnet_group_name => db_subnet_group_name,
#    :backup_retention_period => 0,
    :multi_az => false,
#    :license_model => "bring-your-own-license",
    :publicly_accessible => false
})[:db_instance_identifier]

# Set the appropriate security group - note the API doesn't let us do this
# out of the box.

updated_sgs = rdsClient.modify_db_instance({
    :db_instance_identifier => dbname,
    :vpc_security_group_ids => [private_launch_sg]
})[:vpc_security_groups]

puts update_sgs
