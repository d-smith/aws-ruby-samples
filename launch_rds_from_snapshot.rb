require File.expand_path(File.dirname(__FILE__) + '/config')

def wait_for_available_db(rdsClient, dbName)
  dbAvailable = false
  while !dbAvailable do
    sleep(15)
    puts "Check db status at #{Time.now}"

    dbStatus = rdsClient.describe_db_instances({
        :db_instance_identifier => dbName
    })[:db_instances].first[:db_instance_status]

    if(dbStatus == "available")
      dbAvailable = true
    end
  end
end


(vpc_id, dbname, snapshot_id) = ARGV
unless vpc_id && dbname && snapshot_id
  puts "Usage: launch_rds_from_snapshot <VPC_ID> <dbname> <snapshot_id>"
  exit 1
end

ec2Client = Aws::EC2::Client.new


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
      :values => ["10.0.1.0/24", "10.0.3.0/24"]
    }
  ]
})[:subnets]

subnet_ids = subnet_infos.map do |subnet|
  subnet[:subnet_id]
end

puts subnet_ids



# Need the security group name
sg_infos = ec2Client.describe_security_groups({
    :filters => [
      {
          :name => "vpc-id",
          :values => [vpc_id]
      }
    ]
})[:security_groups]


private_launch_sg = (sg_infos.select {
    |sg| sg[:group_name] == "sqlnet-sg"
  }).first[:group_id]

puts private_launch_sg



# Create an RDS subnet group containing the two private subnets
rdsClient = Aws::RDS::Client::new

db_subnet_group_name = dbname + "-subnet-group"

db_subnet_group = rdsClient.create_db_subnet_group({
    :db_subnet_group_name => db_subnet_group_name,
    :db_subnet_group_description => "VPC DB Subnet Group",
    :subnet_ids => subnet_ids
})



# Create an RDS instance in the VPC
rdsCreateDB = rdsClient.restore_db_instance_from_db_snapshot({
    :db_snapshot_identifier => snapshot_id,
    :db_instance_identifier => dbname,
    :db_instance_class => "db.t1.micro",
    :db_subnet_group_name => db_subnet_group_name,
    :multi_az => false,
    :publicly_accessible => false
})[:db_instance][:db_instance_identifier]



# Wait for the db state to be available
wait_for_available_db(rdsClient, dbname)

# Update the security group
puts "Update vpc security group"
rdsClient.modify_db_instance({
    :db_instance_identifier => dbname,
    :vpc_security_group_ids => [private_launch_sg]
})

puts "Done"
