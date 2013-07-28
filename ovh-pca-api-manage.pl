#! /usr/bin/perl -w
# Written by Thibault Richard. http://hosting.thibs.com
# The following code is released under the terms of either the GNU
# General Public License or the Artistic License
# http://www.opensource.org/licenses/artistic-license-2.0.php
# http://www.gnu.org/licenses/gpl-3.0.txt
#
# V.0.1 - Last updated 28th of July 2013

use warnings;
use strict;
use LWP::UserAgent;
use JSON qw( decode_json );
use HTTP::Date;
use Digest::SHA1 qw(sha1 sha1_hex);
use Getopt::Std;
use POSIX;

#Change your settings here
#my $as='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'; #Put here your  application secret
#my $ck='YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY'; #Put here your consumer key
#my $ak='ZZZZZZZZZZZZZZZZ'; # Put here your application key
my $api_base_url='https://api.ovh.com/1.0/cloud';

#Do not change after this line unless you really know what you're doing
# Define functions usage
sub usage();
sub error($);
sub deletesession_time_based($);
sub deletesession_id($);
sub rename_last_session($);
sub listsessions ();
sub tasksproperties ();
sub restoresession ($);
sub sessionsize ();
# Define internal functions
sub GetOVHtimestamp();
sub CallOVHapi($$$$;$);
sub GetOVHSignature($$$$$;$);

#Create web user agent (=pseudo browser)
my $ua = LWP::UserAgent->new;
$ua->agent("Thibs-OVH-API/0.1 ");

#Get time diffeence between OVH and us
my $ovhtimestamp=GetOVHtimestamp();
my $localtimestamp = time;
my $timestampdifference=$ovhtimestamp-$localtimestamp;

#Get parameters and call right function depending of it
my %opt=();
getopts("d:r:b:ltsh",\%opt) or usage();
usage() if $opt{h};
my $pca_session_delete = $opt{d};
my $pca_session_newname = $opt{r};
my $pca_sessions_torestore = $opt{b};
my $pca_sessions_list = $opt{l};
my $pca_tasks_list = $opt{t};
my $pca_sessions_size = $opt{s};

if ((defined($pca_session_delete))||(defined($pca_session_newname))||(defined($pca_sessions_list))||(defined($pca_tasks_list))||(defined($pca_sessions_torestore))||(defined($pca_sessions_size))) {
	if (defined($pca_session_delete)) {
		if ($pca_session_delete =~ /.{24}/ ) { #A session ID is considered as a 24 characters string
			my $session_id_to_delete=$pca_session_delete;
			deletesession_id($session_id_to_delete);
		}
		elsif($pca_session_delete!~ /\D/ )  { # If it's not a session ID, it's perhaps an expiration time exprimed in seconds
			my $pca_session_max_age=$pca_session_delete;
			deletesession_time_based($pca_session_max_age);
		}
		else { #If it's not a number or a 24 characters string, it's an error
			error("$pca_session_delete is not a valid session ID neither a number");
		}
	}
	if (defined($pca_sessions_torestore)) {
		if ($pca_sessions_torestore !~ /.{24}/ ) { #A session ID is considered as a 24 characters string
			error("$pca_sessions_torestore is not a valid session ID");
		}
		restoresession($pca_sessions_torestore);
	}
	if (defined($pca_session_newname)) {
		rename_last_session($pca_session_newname);
	}
	if (defined($pca_sessions_list)) {
		&listsessions();
	}
	if (defined($pca_tasks_list)) {
		&tasksproperties();
	}
	if (defined($pca_sessions_size)) {
		&sessionsize();
	}
}
else {
	usage();
}
exit(0);

sub usage()
{
  print STDERR << "EOF";
  Multi purpose command line utility on OVH PCA api 

  usage: $0 [-d] max_session_age_in_seconds | [-d] session ID | [-r] new_name | [-l] | [-t] | [-s] | [-b] Session ID | [-h]

   -h : this (help) message
   -d : delete PCA sessions older than X or PCA session ID
   -r : Rename last PCA session into Y
   -l : List PCA sessions
   -s : Total sessions size
   -t : List tasks with their status
   -b : Restore session X

  example:  perl $0 -d 86400 (=delete sessions older than a day)
  	    perl $0 -d 51cbb78fb75806f22f000000 (delete session 51cbb78fb75806f22f000000)
  	    perl $0 -b 51cbb78fb75806f22f000000 (restore session 51cbb78fb75806f22f000000)
            perl $0 -r "new session name" (=rename last session into new session name)
            perl $0 -l (=List active sessions)
            perl $0 -t (=List tasks and get their status)
            perl $0 -s (=Total sessions size)

EOF
  exit;
}

sub error($) {
  print STDERR $_[0] . "\n";
  exit(1);
}

sub rename_last_session($) {
	my $pca_session_newname=$_[0];
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $pca_sessions=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions"));
			my $last_session= pop(@$pca_sessions);
			my $body="{\"name\":\"$pca_session_newname\"}";
			CallOVHapi($as,$ck,'PUT',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$last_session",$body);
			print "Request for renaming session $last_session into $pca_session_newname has been submitted\n";
		}
	}
}

sub deletesession_time_based ($) {
	my $timestamp = time;
	my $pca_session_max_age=$_[0];
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $pca_sessions=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions"));
			foreach my $pca_session( @$pca_sessions ) {
				my $pca_session_properties=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$pca_session"));
				my $session_end_date=$pca_session_properties->{'endDate'};
				my $session_end_date_timestamp=str2time($session_end_date);
				if (($timestamp-$session_end_date_timestamp)>$pca_session_max_age) {
					my $delete_files_instruction=decode_json(CallOVHapi($as,$ck,'DELETE',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$pca_session"));
					my $deletion_date=$delete_files_instruction->{todoDate};
					print "Files from session $pca_session of PCA service $pca_service from OVH cloud service $cloud_service will be deleted at $deletion_date\n";
				}
			}
		}
	}
}

sub deletesession_id($) {
	my $session_id_to_delete=$_[0];
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $delete_files_instruction=decode_json(CallOVHapi($as,$ck,'DELETE',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$session_id_to_delete"));
			my $deletion_date=$delete_files_instruction->{todoDate};
			print "Files from session $session_id_to_delete of PCA service $pca_service from OVH cloud service $cloud_service will be deleted at $deletion_date\n";
		}
	}
}

sub listsessions () {
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $pca_sessions=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions"));
			foreach my $pca_session( @$pca_sessions ) {
				my $pca_session_properties=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$pca_session"));
				my $session_end_date=$pca_session_properties->{'endDate'};
				my $session_name=$pca_session_properties->{'name'};
				my $sesssion_size=$pca_session_properties->{'size'};
				print "Session $pca_session named $session_name ended on $session_end_date has a size of $sesssion_size\n";
			}
		}
	}
}

sub tasksproperties () {
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $pca_tasks=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/tasks"));
			foreach my $pca_task_id( @$pca_tasks ) {
				my $pca_task_properties=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/tasks/$pca_task_id"));
				my $pca_task_function=$pca_task_properties->{'function'};
				my $pca_task_status=$pca_task_properties->{'status'};
				my $pca_task_tododate=$pca_task_properties->{'todoDate'};
				print "Task with ID $pca_task_id requesting task $pca_task_function is in status $pca_task_status (should be executed at $pca_task_tododate) \n";
			}
		}
	}
}

sub restoresession ($) {
	my $pca_session_torestore=$_[0];
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			CallOVHapi($as,$ck,'POST',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$pca_session_torestore/restore");
			print "Request for restoring session $pca_session_torestore has been submitted\n";
		}
	}
}

sub sessionsize () {
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $pca_usage=CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/usage");
			my $pca_usage_in_MB=ceil($pca_usage/1024);
			my $pca_usage_in_GB=ceil($pca_usage_in_MB/1024);
			my $pca_usage_in_TB=ceil($pca_usage_in_GB/1024);
			print "Total usage is currently $pca_usage bytes (=$pca_usage_in_MB MB or $pca_usage_in_GB GB or $pca_usage_in_TB TB)\n";
		}
	}
}

sub CallOVHapi($$$$;$) {
	my $as=$_[0];
	my $ck=$_[1];
	my $method=$_[2];
	my $apiurl=$_[3];
	my $timestamp = GetOVHtimestamp();
	my $signature='';
	my $body='';
	if (defined ($_[4])) {
		$body=$_[4];
	}
	$signature = GetOVHSignature($as,$ck,$method,$apiurl,$timestamp,$body);
	my $req = HTTP::Request->new($method => $apiurl);
	$req->header('Accept' => "application/json");
	$req->header('X-Ovh-Application' => "$ak");
	$req->header('X-Ovh-Timestamp' => "$timestamp");
	$req->header('X-Ovh-Signature' => "$signature");
	$req->header('X-Ovh-Consumer' => "$ck");
	if (defined ($_[4])) {
		$req->header('Content-Type' => 'application/json' );
		$req->content($body);
	}
	my $res = $ua->request($req);
	my $res_content;
	if ($res->is_success) {
		$res_content=$res->content;
	}
	else {
		die $res->status_line, "\n";
	}
	return $res_content;
}

sub GetOVHtimestamp() {
	my $timestamp = time;
	if (defined($timestampdifference)) { #We already knows the time difference between OVH and us
		if ($timestampdifference > 0) {
			$timestamp=$timestamp-$timestampdifference;
		}
		elsif ($timestampdifference < 0) {
			$timestamp=$timestamp+abs($timestampdifference);
		}
	}
	else {
		# Get OVH timestamp
		my $req = HTTP::Request->new(GET => 'https://api.ovh.com/1.0/auth/time');
		my $res = $ua->request($req); 
		if ($res->is_success) { # If no answer, it will fall back to localtime
			$timestamp=$res->content;
		}
	}
	return $timestamp;
}

sub GetOVHSignature($$$$$;$) {
	my $as=$_[0];
	my $ck=$_[1];
	my $method=$_[2];
	my $apiurl=$_[3];
	my $timestamp=$_[4];
	my $body='';
	if (defined ($_[5])) {
		$body=$_[5];
	}
	#Create OVH Signature
	# Format : AS+"+"+CK+"+"+METHOD+"+"+QUERY+"+"+BODY+"+"+TSTAMP
	my $signaturepresha1=$as.'+'.$ck.'+'.$method.'+'.$apiurl.'+'.$body.'+'.$timestamp;
	my $digest = sha1_hex($signaturepresha1);
	my $signature = '$1$'.$digest;
	return $signature;
}