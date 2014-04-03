require File.expand_path(File.dirname(__FILE__) + '/config')



(vpc_id, private_ip) = ARGV
unless vpc_id
	puts "Usage: launch_instances <VPC_ID>"
	exit 1
end

ec2Client = AWS::EC2::Client::new

#
# Grab the subnets from the VPM
#
vpc_infos = ec2Client.describe_vpcs(:vpc_ids => [vpc_id])[:vpc_set]

puts "vpc info array #{vpc_infos}"

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
puts "public subnet id is #{public_subnet}" 
puts "private subnet id is #{private_subnet}"
#puts public_subnet.first[:subnet_id]
#puts subnet_infos.select { |s| s[:availability_zone] == "us-east-1c"}

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


#puts sg_infos

ec2 = AWS::EC2::new
instances = ec2.instances
#instances.each {|i| puts i.id}

# Create instance in the public subnet
ec2.instances.create({
	:image_id => "ami-59a4a230",
	:key_name => "FidoKeyPair",
	:security_group_ids => [launch_sg_id],
	:instance_type => "m1.small",
	:subnet => public_subnet,
	:associate_public_ip_address => true
})

# Create instance in the private subnet
ec2.instances.create({
	:image_id => "ami-59a4a230",
	:key_name => "FidoKeyPair",
	:security_group_ids => [private_subnet_launch_sg_id],
	:instance_type => "m1.small",
	:subnet => private_subnet,
	:private_ip_address => "10.0.1.99"	
})