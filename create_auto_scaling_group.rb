require File.expand_path(File.dirname(__FILE__) + '/config')

(vpc_id, lb_name) = ARGV
unless vpc_id && lb_name
  puts "Usage: create_auto_scaling_group <VPC_ID> <load balancer name>"
  exit 1
end

ec2Client = Aws::EC2::Client::new


# Grab the private subnets. Note this assumes we know the subnets we
# are looking for via knowledge of how the VPC was created.
subnet_infos = ec2Client.describe_subnets({
  :filters => [
    {
      :name => "vpc-id",
      :values => [vpc_id]
    },
    {
      :name => "cidr",
      :values => ["10.0.1.0/24", "10.0.3.0/24"]
    }
  ]
})[:subnets]

subnet_ids = subnet_infos.map do |subnet|
  subnet[:subnet_id]
end


azs = subnet_infos.map do |subnet|
  subnet[:availability_zone]
end


subnet_ids_str = subnet_ids.inject{|l,r| l + "," + r}

puts "subnet ids: '#{subnet_ids_str}'"


cw = Aws::CloudWatch::Client::new


asgClient = Aws::AutoScaling::Client::new

group_base = "b2bnext"
group_name = group_base + "-auto-scaling-group"

asgClient.create_auto_scaling_group({
    :auto_scaling_group_name => group_name,
    :launch_configuration_name => "b2bnext-launch-config",
    :min_size => 1,
    :max_size => 4,
    :default_cooldown => 300,
    :availability_zones => azs,
    :load_balancer_names => [lb_name],
    :health_check_type => "EC2",
    :health_check_grace_period => 300,
    :vpc_zone_identifier => subnet_ids_str
})



scale_up_policy_arn = asgClient.put_scaling_policy({
    :auto_scaling_group_name => group_name,
    :policy_name => "scale up policy",
    :scaling_adjustment => 1,
    :adjustment_type => "ChangeInCapacity",
    :cooldown => 600
})[:policy_arn]


scale_down_policy_arn = asgClient.put_scaling_policy({
    :auto_scaling_group_name => group_name,
    :policy_name => "scale down policy",
    :scaling_adjustment => -1,
    :adjustment_type => "ChangeInCapacity",
    :cooldown => 600
})[:policy_arn]

cw.put_metric_alarm({
    :alarm_name => group_base + " high cpu demo alarm",
    :actions_enabled => true,
    :alarm_actions => [scale_up_policy_arn],
    :metric_name => "CPUUtilization",
    :namespace => "AWS/EC2",
    :statistic => "Average",
    :dimensions => [{:name => "AutoScalingGroupName",:value => group_name}],
    :period=>300,
    :evaluation_periods=>1,
    :threshold=>50.0,
    :comparison_operator=>"GreaterThanOrEqualToThreshold"
})

cw.put_metric_alarm({
    :alarm_name => group_base + " low cpu demo alarm",
    :actions_enabled => true,
    :alarm_actions => [scale_down_policy_arn],
    :metric_name => "CPUUtilization",
    :namespace => "AWS/EC2",
    :statistic => "Average",
    :dimensions => [{:name => "AutoScalingGroupName",:value => group_name}],
    :period=>300,
    :evaluation_periods=>1,
    :threshold=>30.0,
    :comparison_operator=>"LessThanOrEqualToThreshold"
})
