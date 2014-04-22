require File.expand_path(File.dirname(__FILE__) + '/config')

ec2 = AWS::EC2::new
ec2Client = AWS::EC2::Client::new

# Verify connectivity by printing regions
ec2.regions.each { |region| puts region.name }

#Create a VPC
vpc = ec2Client.create_vpc({ :cidr_block => "10.0.0.0/16"})[:vpc]
puts "created vpc #{vpc[:vpc_id]}"

#Create public subnet
subnet1 = ec2Client.create_subnet({
	:vpc_id => vpc[:vpc_id],
	:cidr_block => "10.0.0.0/24",
	:availability_zone => "us-east-1d"
})[:subnet]

puts "created subnet #{subnet1}"


# Create and attach an internet gateway
igw = ec2Client.create_internet_gateway()[:internet_gateway]
puts "created internet gateway #{igw}"

ec2Client.attach_internet_gateway({
	:internet_gateway_id => igw[:internet_gateway_id],
	:vpc_id => vpc[:vpc_id]
})

#Create a route table
routeTable = ec2Client.create_route_table({:vpc_id => vpc[:vpc_id]})[:route_table]
puts "create route table #{routeTable}"

# Create a route to the gateway, and associate it with the subnet
ec2Client.create_route({
	:route_table_id => routeTable[:route_table_id],
	:destination_cidr_block => "0.0.0.0/0",
	:gateway_id => igw[:internet_gateway_id]
})

rtAssociation = ec2Client.associate_route_table({
	:subnet_id => subnet1[:subnet_id],
	:route_table_id => routeTable[:route_table_id]
})[:association_id]

puts "Associated route to subnet - #{rtAssociation}"

# Create two private subnets (RDS needs two availability zones), and tag them
# as private
privateSubnet = ec2Client.create_subnet({
	:vpc_id => vpc[:vpc_id],
	:cidr_block => "10.0.1.0/24",
	:availability_zone => "us-east-1c"
})[:subnet]

privateSubnet2 = ec2Client.create_subnet({
	:vpc_id => vpc[:vpc_id],
	:cidr_block => "10.0.2.0/24",
	:availability_zone => "us-east-1a"
})[:subnet]

ec2Client.create_tags({
		:resources => [
			privateSubnet[:subnet_id],
			privateSubnet2[:subnet_id]
		],
		:tags => [{:key => "access", :value => "private"}]
})

# Create a security group allowing inbound ssh from anywhere. This will be used in launching
# EC2 instances in the public subnet
launch_group_id = ec2Client.create_security_group({
	:group_name => "launch-sg",
	:description => "launch-sg",
	:vpc_id => vpc[:vpc_id]
})[:group_id]

puts("created security group #{launch_group_id}")

ec2Client.authorize_security_group_ingress({
	:group_id => launch_group_id,
	:ip_permissions => [
		{:ip_protocol => "tcp",
		 :from_port => 22,
		 :to_port => 22,
		 :ip_ranges => [
		 	{:cidr_ip => "0.0.0.0/0"}
		 ]
		}
	]
})


# Create a security group allowing access from the VPC. This will be used when launching private instances.
private_launch_group_id = ec2Client.create_security_group({
	:group_name => "private-subnet-launch-sg",
	:description => "private-subnet-launch-sg",
	:vpc_id => vpc[:vpc_id]
})[:group_id]

puts("created private subnet launch sg #{private_launch_group_id}")

ec2Client.authorize_security_group_ingress({
	:group_id => private_launch_group_id,
	:ip_permissions => [
		{:ip_protocol => "tcp",
		 :from_port => 22,
		 :to_port => 22,
		 :ip_ranges => [
		 	{:cidr_ip => "10.0.0.0/16"}
		 ]
		 },
		 {
				:ip_protocol => "tcp",
				:from_port => 9000,
				:to_port => 9000,
				:ip_ranges => [
					{:cidr_ip => "10.0.0.0/16"}
				]
			}
		]
})

# Create a security group to allow SQL*Net traffic on port 1521
# from the private launch sg
sqlnet_sg_id = ec2Client.create_security_group({
	:group_name => "sqlnet-sg",
	:description => "SQLNet access from VPC private subnets",
	:vpc_id => vpc[:vpc_id]
})[:group_id]

puts("created sqlnet sg #{sqlnet_sg_id}")

ec2Client.authorize_security_group_ingress({
	:group_id => sqlnet_sg_id,
	:ip_permissions => [
		{:ip_protocol => "tcp",
		:from_port => 1521,
		:to_port => 1521,
		:ip_ranges => [
			{:cidr_ip => "10.0.1.0/24"}
		]
	},
	{:ip_protocol => "tcp",
	:from_port => 1521,
	:to_port => 1521,
	:ip_ranges => [
		{:cidr_ip => "10.0.2.0/24"}
	]
	}
	]
})

load_balancer_sg = ec2Client.create_security_group({
	:group_name => "load_balancer_sg",
	:description => "Load balancer security group",
	:vpc_id => vpc[:vpc_id]
})[:group_id]

puts("created load balancer security group #{load_balancer_sg}")

ec2Client.authorize_security_group_ingress({
	:group_id => load_balancer_sg,
	:ip_permissions => [
		{:ip_protocol => "tcp",
		:from_port => 80,
		:to_port => 80,
		:ip_ranges => [
			{:cidr_ip => "0.0.0.0/0"}
		]
		}
	]
})

puts "finished configuration of #{vpc[:vpc_id]}"
