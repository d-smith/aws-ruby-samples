require File.expand_path(File.dirname(__FILE__) + '/config')

def wait_for_group_creation(sg)
  created = false
  while !created do
    sleep(2)
    created = sg.exists?
  end
end



(vpc_id, dummyarg) = ARGV
unless vpc_id
  puts "Usage: create_security_groups <VPC_ID>"
  exit 1
end

ec2 = AWS::EC2::new


vpc = ec2.vpcs.filter('vpc-id', vpc_id).first

security_groups = vpc.security_groups()

# Create the security group used to launch instances in the public subnets
launch_sg = security_groups.create("launch-sg", {
    :description => "launch-sg",
    :vpc => vpc
})

wait_for_group_creation(launch_sg)

launch_sg.authorize_ingress(:tcp, 22, "192.223.128.0/17") 

# Create the security group for the load balancer
load_balancer_sg = security_groups.create("load_balancer_sg", {
    :description => "Load balancer security group",
    :vpc => vpc
})

wait_for_group_creation(load_balancer_sg)

load_balancer_sg.authorize_ingress(:tcp, 80, "0.0.0.0/0")

# Create the security group used to launch instances in the private subnets.
# Authorize ingress from anything launched using the launch_sg
private_launch_sg = security_groups.create("private-subnet-launch-sg", {
    :description => "private-subnet-launch-sg",
    :vpc => vpc
})

wait_for_group_creation(private_launch_sg)

private_launch_sg.authorize_ingress(:tcp, 22, launch_sg)
private_launch_sg.authorize_ingress(:tcp, 9000, launch_sg)
private_launch_sg.authorize_ingress(:tcp, 9000, load_balancer_sg)

# Create a database security group to allow SQL*Net traffic from
# instances launched using the private-subnet-launch-sg
sqlnet_sg = security_groups.create("sqlnet-sg", {
    :description => "SQLNet access from VPC private subnets",
    :vpc => vpc
})

wait_for_group_creation(sqlnet_sg)

sqlnet_sg.authorize_ingress(:tcp, 1521, private_launch_sg)



# Create a security group for the NAT
nat_sg = security_groups.create("nat_sg", {
  :description => "NAT instance security group",
  :vpc => vpc
})

wait_for_group_creation(nat_sg)

nat_sg.authorize_ingress(:tcp, 80, private_launch_sg)
nat_sg.authorize_ingress(:tcp, 443, private_launch_sg)
nat_sg.authorize_ingress(:tcp, 22, launch_sg)
