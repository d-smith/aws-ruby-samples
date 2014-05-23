require File.expand_path(File.dirname(__FILE__) + '/config')

def create_public_facing_subnets(ec2Client, cidr, az, vpc, routeTable)
  # Create the subnet
  subnet = ec2Client.create_subnet({
    :vpc_id => vpc[:vpc_id],
    :cidr_block => cidr,
    :availability_zone => az
  })[:subnet]

  puts "created subnet #{subnet}"



  rtAssociation = ec2Client.associate_route_table({
    :subnet_id => subnet[:subnet_id],
    :route_table_id => routeTable[:route_table_id]
  })[:association_id]

  puts "Associated route to subnet - #{rtAssociation}"

end

def create_private_subnets(ec2Client, cidr, az, vpc)
    privateSubnet = ec2Client.create_subnet({
      :vpc_id => vpc[:vpc_id],
      :cidr_block => cidr,
      :availability_zone => az
    })[:subnet]

    ec2Client.create_tags({
        :resources => [
          privateSubnet[:subnet_id]
        ],
        :tags => [{:key => "access", :value => "private"}]
    })
end

ec2 = AWS::EC2::new
ec2Client = AWS::EC2::Client::new

#Create a VPC
vpc = ec2Client.create_vpc({ :cidr_block => "10.0.0.0/16"})[:vpc]
puts "created vpc #{vpc[:vpc_id]}"

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

# Create two public subnets
create_public_facing_subnets(ec2Client, "10.0.0.0/24", "us-east-1a", vpc,  routeTable)
create_public_facing_subnets(ec2Client, "10.0.2.0/24", "us-east-1c", vpc,  routeTable)

# Create two private subnets (RDS needs two availability zones), and tag them
# as private
create_private_subnets(ec2Client, "10.0.1.0/24", "us-east-1a", vpc)
create_private_subnets(ec2Client, "10.0.3.0/24", "us-east-1c", vpc)

puts "finished configuration of #{vpc[:vpc_id]}"
