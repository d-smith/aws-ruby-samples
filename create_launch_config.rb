require File.expand_path(File.dirname(__FILE__) + '/config')

(vpc_id, dummy) = ARGV
unless vpc_id
  puts "Usage: create_launch_config <VPC_ID>"
  exit 1
end

ec2Client = Aws::EC2::Client::new

#Use our custom AMI id
ami_id = 'ami-c49174ac'

#Copy out war into the tomcat webapps directory when the instance is
#spun up - user data is the following two lines base-64 encoded.
#$!/bin/sh
#aws s3 cp s3://xt-war-buckets/b2bnext-webapp.war /var/lib/tomcat7/webapps
user_data = 'IyEvYmluL3NoDQphd3MgczMgY3AgczM6Ly94dC13YXItYnVja2V0cy9iMmJuZXh0LXdlYmFwcC53YXIgL3Zhci9saWIvdG9tY2F0Ny93ZWJhcHBz'

#Need the security group name
sg_infos = ec2Client.describe_security_groups({
    :filters => [
      {
          :name => "vpc-id",
          :values => [vpc_id]
      }
    ]
})[:security_groups]



private_launch_sg = (sg_infos.select {
    |sg| sg[:group_name] == "private-subnet-launch-sg"
  }).first[:group_id]

puts "private launch security group id #{private_launch_sg}"


asgClient = Aws::AutoScaling::Client::new
exit

asgClient.create_launch_configuration({
    :launch_configuration_name => "b2bnext-launch-config",
    :image_id => ami_id,
    :key_name => "chef",
    :security_groups => [private_launch_sg],
    :user_data => user_data,
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
    ],
    :iam_instance_profile => 'arn:aws:iam::930295567417:instance-profile/war-deployer-role'
})
