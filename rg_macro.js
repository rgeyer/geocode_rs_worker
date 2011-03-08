// Copyright (c) 2007-2009 RightScale Inc
// Create deployment, bucket, queues, and array for a RightGrid setup

// Get a timestamp to help make bucket, queue, ssh key, security group, and deployment names unique
var d = new Date();
var now = d.getTime();

var rundir = '/mnt/rightgrid';
var worker_template_href = 'https://my.rightscale.com/api/acct/7954/ec2_server_templates/50434';
var jc_template_href = 'https://my.rightscale.com/api/acct/7954/ec2_server_templates/50435';

var appname = "RightGrid_Census_Geo_App_";

var bucket_name = appname + _account_id + "_" + now;
var input_queue_name = now + "_" + appname + "Input";
var output_queue_name = now + "_" + appname + "Output";
var audit_queue_name = now + "_" + appname + "Audit";
var error_queue_name = now + "_" + appname + "Error";

input_queue = create_queue({'name': input_queue_name});
output_queue = create_queue({'name': output_queue_name});
audit_queue = create_queue({'name': audit_queue_name});
error_queue = create_queue({'name': error_queue_name});
bucket = create_bucket({'name': bucket_name});

ec2_ssh_key = create_ec2_ssh_key(
		{
		'aws_key_name':appname + now
		}
		);

ec2_security_group = create_ec2_security_group(
		{
		'aws_description':'Security group for the RightGrid Census Geo application',
		'aws_group_name':appname + now
		}
		);
add_ingress_rule(ec2_security_group,
		{
		'cidr_ips':'0.0.0.0/0',
		'from_port':'22',
		'protocol':'tcp',
		'to_port':'22'
		}
		);
add_ingress_rule(ec2_security_group,
		{
		'cidr_ips':'0.0.0.0/0',
		'from_port':'80',
		'protocol':'tcp',
		'to_port':'80'
		}
		);

deployment_url = create_deployment(
		{
		'description':'',
		'nickname':appname + now
		}
		);

my_worker_template = clone_server_template(worker_template_href);
my_coordinator_template = clone_server_template(jc_template_href);

set_server_template_parameter(my_worker_template,
		{
		'parameters':
		{
		'DEMO_APP_BUCKET' : 'text:' + bucket_name,
		'DEMO_APP_INPUT_QUEUE' : 'text:' + input_queue_name,
		'DEMO_APP_OUTPUT_QUEUE' : 'text:' + output_queue_name,
		'DEMO_APP_AUDIT_QUEUE' : 'text:' + audit_queue_name,
		'DEMO_APP_ERROR_QUEUE' : 'text:' + error_queue_name,
		'RUNDIR' : 'text:' + rundir,
    'RAILS_ENV' : 'text:development'
		}
		}
		);

set_deployment_parameter(deployment_url,
		{
		'parameters':
		{
		'DEMO_APP_BUCKET': 'text:' + bucket_name,
		'DEMO_APP_INPUT_QUEUE':'text:' + input_queue_name,
		'DEMO_APP_OUTPUT_QUEUE':'text:' + output_queue_name,
		'DEMO_APP_AUDIT_QUEUE':'text:' + audit_queue_name,
	  'DEMO_APP_ERROR_QUEUE' : 'text:' + error_queue_name,
	  'REPORT_EMAIL_ADDR' : 'text:root@localhost',
    'RUNDIR':'text:' + rundir,
    'RAILS_ENV' : 'text:development'
		}
		}
		);

coordinator_server = create_ec2_server(
		{
		'ec2_ssh_key_href':ec2_ssh_key,
		'aki_image_href':null,
		'ec2_security_group_href':ec2_security_group,
		'server_template_href':my_coordinator_template,
		'ec2_availability_zone':null,
		'nickname':'Job Coordinator',
		'deployment_href':deployment_url,
		'instance_type':null,
		'ec2_elastic_ip_href':null,
		'ari_image_href':null,
		'ec2_image_href':null
		}
		);

server_array = create_server_array(
		{
		'elasticity_params':
		{
		'items_per_instance':'10'
		},
		'elasticity':
		{
		'max_count':'20',
		'resize_down_by':'1',
		'min_count':'0',
		'resize_up_by':'1',
		'resize_calm_time':null,
		'decision_threshold':'51'
		},
		'ec2_ssh_key_href': ec2_ssh_key,
		'elasticity_function':'sqs_queue_size',
		'deployment_href':deployment_url,
		'ec2_security_group_href':ec2_security_group,
		'indicator_href': input_queue,
		'audit_queue_href':audit_queue,
		'description':'',
		'server_template_href': my_worker_template,
		'active':'true',
		'array_type':'queue',
		'nickname':appname + now
		}
		);
start_server(coordinator_server);
alert("RightGrid Census Geo App created.  Open a SSH console to the Job Coordinator Server to begin running RightGrid.");