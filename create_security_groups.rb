require File.expand_path(File.dirname(__FILE__) + '/config')
require File.expand_path(File.dirname(__FILE__) + '/get_vpc_status')

def create_security_group(ec2, group_name, vpc_id)
  ec2.create_security_group(
    group_name: group_name,
    description: group_name,
    vpc_id: vpc_id
  )[:group_id]
end

def authorize_ingress(ec2, sg_id, port, cidr_ip)
  ec2.authorize_security_group_ingress(
    group_id: sg_id,
    ip_permissions: [
      {
        ip_protocol: "tcp",
        to_port: port,
        from_port: port,
        ip_ranges:[
          {
            cidr_ip: cidr_ip,
          }
        ]
      },
    ]
  )
end

(vpc_id, dummyarg) = ARGV
unless vpc_id
  puts "Usage: create_security_groups <VPC_ID>"
  exit 1
end

ec2 = Aws::EC2::Client.new


vpc = get_vpc(ec2, vpc_id)


launch_sg = create_security_group(ec2, "launch-sg", vpc_id)
puts "created sg #{launch_sg}"
authorize_ingress(ec2, launch_sg, 22, "192.223.128.0/17")

exit
#TODO - resume port

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
