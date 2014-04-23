require File.expand_path(File.dirname(__FILE__) + '/config')

(vpc_id, ami_id) = ARGV
unless vpc_id && ami_id
  puts "Usage: create_launch_config <VPC_ID> <ami_id>"
  exit 1
end

ec2Client = AWS::EC2::Client::new

#Need the security group name
sg_infos = ec2Client.describe_security_groups({
    :filters => [
      {
          :name => "vpc-id",
          :values => [vpc_id]
      }
    ]
})[:security_group_info]

private_launch_sg = (sg_infos.select {
    |sg| sg[:group_name] == "private-subnet-launch-sg"
  }).first[:group_id]

puts "private launch security group id #{private_launch_sg}"

asgClient = AWS::AutoScaling::Client::new


asgClient.create_launch_configuration({
    :launch_configuration_name => "b2bnext-launch-config",
    :image_id => ami_id,
    :key_name => "chef",
    :security_groups => [private_launch_sg],
    :instance_type => "t1.micro",
    :associate_public_ip_address => false,
    :instance_monitoring => { :enabled => false },
    :block_device_mappings=>[
      {
        :device_name=>"/dev/sda1",
        :ebs=>
          {
            :delete_on_termination=>true,
            :volume_type=>"standard",
            :volume_size=>8
          }
      }
    ]
})
