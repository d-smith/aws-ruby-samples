require File.expand_path(File.dirname(__FILE__) + '/config')


(vpc_id, load_balancer_name) = ARGV
unless vpc_id && load_balancer_name
  puts "Usage: create_load_balancer <VPC_ID> <load_balancer_name>"
  exit 1
end

ec2Client = AWS::EC2::Client::new


# Grab the private subnets. Note this assumes we know the subnets we
# are looking for via knowledge of how the VPC was created.
subnet_infos = ec2Client.describe_subnets({
  :filters => [
    {
      :name => "vpc-id",
      :values => [vpc_id]
    }
  ]
})[:subnet_set]

subnet_ids = subnet_infos.map do |subnet|
  subnet[:subnet_id]
end

puts "subnet ids #{subnet_ids}"

# Need the security group subnet
sg_infos = ec2Client.describe_security_groups({
    :filters => [
      {
          :name => "vpc-id",
          :values => [vpc_id]
      }
    ]
})[:security_group_info]


load_balancer_sg = (sg_infos.select {
    |sg| sg[:group_name] == "load_balancer_sg"
  })

puts "load balancer sg array is #{load_balancer_sg}"

load_balancer_sg_ids = load_balancer_sg.map do |sg|
  sg[:group_id]
end

elbClient = AWS::ELB::Client::new

# Create the load balancer
dns_name = elbClient.create_load_balancer({
  :load_balancer_name => load_balancer_name,
  :listeners => [
    {
      :protocol => "HTTP",
      :load_balancer_port => 80,
      :instance_protocol => "HTTP",
      :instance_port => 9000
    }
  ],
  :subnets => subnet_ids,
  :security_groups => load_balancer_sg_ids
})[:dns_name]

puts "Created load balancer with DNS name #{dns_name}"

#Add the health check
health_check = elbClient.configure_health_check({
  :load_balancer_name => load_balancer_name,
  :health_check => {
    :target => "HTTP:9000/b2bnext-webapp/",
    :interval => 30,
    :timeout => 5,
    :unhealthy_threshold => 2,
    :healthy_threshold => 4
  }
})[:health_check]
