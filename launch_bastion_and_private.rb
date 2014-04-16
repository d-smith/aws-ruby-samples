require File.expand_path(File.dirname(__FILE__) + '/config')



(vpc_id, private_ip) = ARGV
unless vpc_id
	puts "Usage: launch_instances <VPC_ID>"
	exit 1
end

ec2Client = AWS::EC2::Client::new

#
# Get the subnets from the VPC. Here we assume the public subnet is in us-east-1d, and the private
# subnet is in us-east-1c
#
subnet_infos = ec2Client.describe_subnets({
	:filters => [
		{
			:name => "vpc-id",
			:values => [vpc_id]
		}
	]
})[:subnet_set]


public_subnet = (subnet_infos.select { |s| s[:availability_zone] == "us-east-1d"}).first[:subnet_id]
private_subnet = (subnet_infos.select { |s| s[:availability_zone] == "us-east-1c"}).first[:subnet_id]

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
})[:security_group_info]

launch_sg_id = (sg_infos.select { |sg| sg[:group_name] == "launch-sg"}).first[:group_id]
private_subnet_launch_sg_id = (sg_infos.select { |sg| sg[:group_name] == "private-subnet-launch-sg"}).first[:group_id]



ec2 = AWS::EC2::new
instances = ec2.instances

# Create instance in the public subnet using the Ubuntu 12.04 AMI
ec2.instances.create({
	:image_id => "ami-59a4a230",
	:key_name => "FidoKeyPair",
	:security_group_ids => [launch_sg_id],
	:instance_type => "t1.micro",
	:subnet => public_subnet,
	:associate_public_ip_address => true
})

# Create instance in the private subnet using my chef Workstation AMI
ec2.instances.create({
	:image_id => "ami-db716eb2",
	:key_name => "chef",
	:security_group_ids => [private_subnet_launch_sg_id],
	:instance_type => "t1.micro",
	:subnet => private_subnet,
	:associate_public_ip_address => false
#	:private_ip_address => "10.0.1.99"
})
