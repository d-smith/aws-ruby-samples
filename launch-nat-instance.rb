require File.expand_path(File.dirname(__FILE__) + '/config')



(vpc_id, dummy) = ARGV
unless vpc_id
  puts "Usage: launch-nat-instance <VPC_ID>"
  exit 1
end

def get_subnet_id(ec2Client, vpc, cidr)
  subnet_infos = ec2Client.describe_subnets({
    :filters => [
      {
        :name => "vpc-id",
        :values => [vpc]
      }
    ]
  })[:subnets]


  (subnet_infos.select { |s| s[:cidr_block] == cidr}).first[:subnet_id]
end

def wait_for_instance_running(instance)
  running = false
  while !running do
    if instance.status == :running
      running = true
    end
  end
end

ec2Client = Aws::EC2::Client.new

# Get a public subnet id to launch the instance in
public_subnet_id = get_subnet_id(ec2Client, vpc_id, "10.0.2.0/24")
puts public_subnet_id

#
# Get the security groups for launching public and private instances
#
sg_infos = ec2Client.describe_security_groups({
  :filters => [
    {
      :name => "vpc-id",
      :values => [vpc_id]
    }
  ]
})[:security_groups]


launch_sg_id = (sg_infos.select { |sg| sg[:group_name] == "sg_nat"}).first[:group_id]





# Create instance in the public subnet using amzn-ami-vpc-nat-pv-2013.09.0.x86_64-ebs AMI
#nat_instance = ec2.instances.create({
#  :image_id => "ami-ad227cc4",
#  :key_name => "FidoKeyPair",
#  :security_group_ids => [launch_sg_id],
#  :instance_type => "t1.micro",
#  :subnet => public_subnet_id,
#  :associate_public_ip_address => true
#})

nat_instance = ec2Client.run_instances({
    image_id: "ami-ad227cc4",
    min_count: 1,
    max_count: 1,
    key_name: "FidoKeyPair",

    instance_type: "t1.micro",

    network_interfaces: [
      {
        device_index: 0,
        subnet_id: public_subnet_id,
        associate_public_ip_address: true,
        groups: [launch_sg_id],
      }
    ]
})

puts "launched NAT instance #{nat_instance}"
exit

wait_for_instance_running(nat_instance)

puts "source/dest check is #{nat_instance.source_dest_check}"
nat_instance.source_dest_check = false

puts "instance is running - add it to route table"

rt_id = ec2Client.describe_route_tables({
    :filters => [
      {
        :name => "vpc-id",
        :values => [vpc_id]
      },
      {
        :name => "association.main",
        :values => ["true"]
      }
    ]
  })[:route_table_set].first[:route_table_id]

puts rt_id

ec2Client.create_route({
  :route_table_id => rt_id,
  :destination_cidr_block => "0.0.0.0/0",
  :instance_id => nat_instance.id
})

puts "added NAT instance to main route table"
