Overview
-----------------

The create_vpn.rb script creates a VPC with four subnets - two public and two
private. For this sample we need two AZs for our VPC-specific RDS instance.

![VPC topology](vpc.png "VPC Topology")

Note for elastic load balancing, load balancers are placed in public subnets,
with security group ingress configuration for the private subnets gating
access. So for this sample we create two public subnets (one in each AZ) to
allow ELB to route traffic to private servers in the AZs.


Permissions
----------------

Running the scripts required some additional policies granting API access
for load balancer and auto scaling configuration. Here are the
additional policies I had to create:

    {
      "Version": "2012-10-17",
      "Statement":[{
      "Effect":"Allow",
      "Action":[
          "autoscaling:*LaunchConfiguration*",
          "autoscaling:*DescribeAutoScalingGroups*",
          "autoscaling:DescribePolicies",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:PutScalingPolicy"
      ],
      "Resource":"*"
      }
      ]
    }

    {
      "Version": "2012-10-17",
       "Statement":[{
          "Effect":"Allow",
          "Action":["cloudwatch:DescribeAlarms",
                    "cloudwatch:PutMetricAlarm"
          ],
          "Resource":"*"
          }  
       ]
    }

    {
      "Version": "2012-10-17",
      "Statement":[{
        "Effect":"Allow",
        "Action":["elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:DeleteLoadBalancer"],
                "Resource":"*"
              }  
      ]
    }  




Oracle Connection Details
-----------------------------

To connect to the RDS instance, launch an EC2 server in the VPC. You will need to install the Oracle instant
client - grab it from the OTN [here](http://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html)

You will need the basic and sqlplus RPMs.

The RPMs are installed via

    rpm -i oracle-instantclient12.1-basic-12.1.0.1.0-1.x86_64.rpm
    rpm -i oracle-instantclient12.1-sqlplus-12.1.0.1.0-1.x86_64.rpm

The lib and bin directories located here:

    /usr/lib/oracle/12.1/client64/lib
    /usr/lib/oracle/12.1/client64/bin

To use sqlplus, update your PATH and LD_LIBRARY_PATH settings in your .bash_profile

    PATH=$PATH:$HOME/bin:/usr/lib/oracle/12.1/client64/bin
    LD_LIBRARY_PATH=/usr/lib/oracle/12.1/client64/lib:$LD_LIBRARY_PATH
    export PATH
    export LD_LIBRARY_PATH

Now you can connect to your oracle RDS instance:

    sqlplus 'user@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=aws-host)(PORT=1521))(CONNECT_DATA=(SID=RDS-SID)))'

When I tried this initially, I received the following error:

    ERROR:
    ORA-21561: OID generation failed

The solution was to edit /etc/hosts to include the hostname in the localhost line:

    127.0.0.1   localhost ip-10-0-0-93


Ruby Setup - Vagrant VM
--------------------------

Working behind an HTTP proxy? Export http_proxy and https_proxy variables in
.bashrc and source it.

You will need to have those variables propogate to the sudo context as well. To
do so, edit /etc/sudoers and add two defaults.

    Defaults  env_keep += "http_proxy"
    Defaults  env_keep += "https_proxy"

Now grab curl, and install RVM

    sudo apt-get install curl
    curl -sSL https://get.rvm.io | bash -s stable --ruby

Follow the post install instructions, e.g.

    source /home/vagrant/.rvm/scripts/rvm

Install and configure git

    sudo apt-get install git
    git config --global http.proxy <proxy-url>
    git config --global https.proxy <proxy-url>
    git config --global user.name <user name>
    git config --global user.email <email>
  


Now install the AWS gem

    gem install --http-proxy <proxy-url-and-port> aws-sdk
