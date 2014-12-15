require File.expand_path(File.dirname(__FILE__) + '/config')

def get_vpc_state(ec2, vpc_id)
	vpc = ec2.vpcs.filter('vpc-id', vpc_id).first
	vpc.state
end

def wait_until_vpc_available(ec2, vpc_id)
	available = get_vpc_state(ec2, vpc_id)
 	while available != :available do
	    sleep(2)
	    available = get_vpc_state(ec2, vpc_id)
	end
end	


