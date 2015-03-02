require File.expand_path(File.dirname(__FILE__) + '/config')

def get_vpc(ec2, vpc_id)
	vpcs = ec2.describe_vpcs(vpc_ids: [vpc_id],
		filters: [{name: "vpc-id",values:[vpc_id]}])
	vpcs[:vpcs][0]
end

def get_vpc_state(ec2, vpc_id)

	vpcs = ec2.describe_vpcs(vpc_ids: [vpc_id],
		filters: [{name: "vpc-id",values:[vpc_id]}])

	desc = vpcs[:vpcs][0]
	desc[:state]
end

def wait_until_vpc_available(ec2, vpc_id)
	available = get_vpc_state(ec2, vpc_id)
 	while available != "available" do
	    sleep(2)
	    available = get_vpc_state(ec2, vpc_id)
	end
end
