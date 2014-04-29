require File.expand_path(File.dirname(__FILE__) + '/config')

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

launch_sg.authorize_ingress(:tcp, 22, "0.0.0.0/0")

# Create the security group used to launch instances in the private subnets.
# Authorize ingress from anything launched using the launch_sg
private_launch_sg = security_groups.create("private-subnet-launch-sg", {
    :description => "private-subnet-launch-sg",
    :vpc => vpc
})

private_launch_sg.authorize_ingress(:tcp, 22, launch_sg)
private_launch_sg.authorize_ingress(:tcp, 9000, launch_sg)
