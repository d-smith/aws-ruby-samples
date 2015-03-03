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

def authorize_ingress_from_sg(ec2, sg_id, port, traffic_src_sg)
  ec2.authorize_security_group_ingress(
    group_id: sg_id,
    ip_permissions: [
      {
        ip_protocol: "tcp",
        to_port: port,
        from_port: port,
        user_id_group_pairs:[
          {
            group_id: traffic_src_sg,
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


load_balancer_sg = create_security_group(ec2, "load_balancer_sg", vpc_id)
puts "created sg #{load_balancer_sg}"
authorize_ingress(ec2, load_balancer_sg, 80, "0.0.0.0/0")


# Create the security group used to launch instances in the private subnets.
# Authorize ingress from anything launched using the launch_sg
private_launch_sg = create_security_group(ec2, "private-subnet-launch-sg",vpc_id)
puts "created sg #{private_launch_sg}"


authorize_ingress_from_sg(ec2, private_launch_sg, 22, launch_sg)
authorize_ingress_from_sg(ec2, private_launch_sg, 9000, launch_sg)
authorize_ingress_from_sg(ec2, private_launch_sg, 9000, load_balancer_sg)


# Create a database security group to allow SQL*Net traffic from
# instances launched using the private-subnet-launch-sg
sqlnet_sg = create_security_group(ec2, "sqlnet-sg", vpc_id)
puts "created sg #{sqlnet_sg}"
authorize_ingress_from_sg(ec2, sqlnet_sg, 1521, private_launch_sg)


nat_sg = create_security_group(ec2, "sg_nat", vpc_id)
puts "created #{nat_sg}"
authorize_ingress_from_sg(ec2, nat_sg, 80, private_launch_sg)
authorize_ingress_from_sg(ec2, nat_sg, 443, private_launch_sg)
authorize_ingress_from_sg(ec2, nat_sg, 22, launch_sg)
