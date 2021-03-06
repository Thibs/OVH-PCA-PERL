#! /usr/bin/perl -w
# Written by Thibault Richard. http://hosting.thibs.com
# The following code is released under the terms of either the GNU
# General Public License or the Artistic License
# http://www.opensource.org/licenses/artistic-license-2.0.php
# http://www.gnu.org/licenses/gpl-3.0.txt
#
# V.0.9 - Last updated 3rd of October 2013
# v.0.91 - Modification tu use sha instead of sha1

use warnings;
use strict;
use LWP::UserAgent;
use JSON qw( decode_json );
use HTTP::Date;
use Digest::SHA qw(sha1 sha1_hex);
use Getopt::Std;

#Change your settings here
my $as='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'; #Put here your  application secret
my $ck='YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY'; #Put here your consumer key
my $ak='ZZZZZZZZZZZZZZZZ'; # Put here your application key
my $api_base_url='https://api.ovh.com/1.0/cloud';

#Do not change after this line unless you really know what you're doing
# Define functions usage
sub usage();
sub error($);
sub deletesession_time_based($);
sub deletesession_id($);
sub rename_session($;$);
sub listsessions ();
sub tasksproperties ();
sub restoresession ($);
sub listfilesession ($);
sub sessionsize ();
# Define internal functions
sub GetOVHtimestamp();
sub CallOVHapi($$$$;$);
sub GetOVHSignature($$$$$;$);
sub trim($);

#Create web user agent (=pseudo browser)
my $ua = LWP::UserAgent->new;
$ua->agent("Thibs-OVH-API/0.1 ");

#Get time difference between OVH and us
my $ovhtimestamp=GetOVHtimestamp();
my $localtimestamp = time;
my $timestampdifference=$ovhtimestamp-$localtimestamp;

#Get parameters from command line
my %opt=();
getopts("d:r:b:f:ltsh",\%opt) or usage();
usage() if $opt{h};
my $pca_session_delete = $opt{d};
my $pca_session_newname = $opt{r};
my $pca_sessions_torestore = $opt{b};
my $pca_sessions_filelist = $opt{f};
my $pca_sessions_list = $opt{l};
my $pca_tasks_list = $opt{t};
my $pca_sessions_size = $opt{s};

#Call right function depending on parameters
if ((defined($pca_session_delete))||(defined($pca_session_newname))||(defined($pca_sessions_list))||(defined($pca_tasks_list))||(defined($pca_sessions_torestore))||(defined($pca_sessions_size))||(defined($pca_sessions_filelist))) {
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
	if (defined($pca_sessions_filelist)) {
		if ($pca_sessions_filelist !~ /.{24}/ ) { #A session ID is considered as a 24 characters string
			error("$pca_sessions_filelist is not a valid session ID");
		}
		listfilesession($pca_sessions_filelist);
	}
	if (defined($pca_session_newname)) {
		my @newnamesplit = split(/\s+/,$pca_session_newname);
		if ($newnamesplit[0] =~ /.{24}/ ) { #If the first part of -r parameter is a 24 characters string, it's considered as a session ID
			my $sessiontorename=$newnamesplit[0];
			$pca_session_newname=trim(substr $pca_session_newname, 24);
			rename_session($pca_session_newname,$sessiontorename);
		}
		else { #Everything behind the -r parameter is the new name for the last session
			rename_session($pca_session_newname);
		}
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

  usage: $0 [-d] max_session_age_in_seconds | [-d] session ID | [-f] session ID | [-b] Session ID | [-r] new_name | [-r] "Session ID new_name" | [-l] | [-t] | [-s] | [-h]

   -h : this (help) message
   -d : delete PCA sessions older than X (exprimed in seconds) or PCA session ID
   -f : List files from PCA session ID 
   -r : Rename last PCA session into Y
   -r : Rename PCA session ID into Z
   -l : List PCA sessions
   -s : Total sessions size
   -t : List tasks with their status
   -b : Restore session X

  example:  perl $0 -d 86400 (=delete sessions older than a day)
  	    perl $0 -d 51cbb78fb75806f22f000000 (delete session 51cbb78fb75806f22f000000)
  	    perl $0 -f 51cbb78fb75806f22f000000 (list files contained in session 51cbb78fb75806f22f000000)
  	    perl $0 -b 51cbb78fb75806f22f000000 (restore session 51cbb78fb75806f22f000000)
            perl $0 -r "new session name" (=rename last session into "new session name")
  	    perl $0 -r "51cbb78fb75806f22f000000 new session name" (=rename session 51cbb78fb75806f22f000000 into "new session name")
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

sub rename_session($;$) {
	my $pca_session_newname=$_[0];
	my $body="{\"name\":\"$pca_session_newname\"}";
	my $session_id_to_rename='';
	if (defined ($_[1])) {
		$session_id_to_rename=$_[1];
	}	
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			unless (defined ($_[1])) {
				my $pca_sessions=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions"));
				$session_id_to_rename=pop(@$pca_sessions);
			}
			CallOVHapi($as,$ck,'PUT',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$session_id_to_rename",$body);
			print "Request for renaming session $session_id_to_rename into $pca_session_newname has been submitted\n";
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

sub listfilesession ($) {
	my $session_id_to_list=$_[0];
	my $available_cloud_services=decode_json(CallOVHapi($as,$ck,'GET',$api_base_url));
	foreach my $cloud_service( @$available_cloud_services ) { 
		my $available_pca_services=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca"));
		foreach my $pca_service( @$available_pca_services ) {
			my $pca_sessions_fileslist=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$session_id_to_list/files"));
			print "PCA session $session_id_to_list is containing following files :\n";
			foreach my $file_in_session( @$pca_sessions_fileslist ) {
				my $file_in_session_properties=decode_json(CallOVHapi($as,$ck,'GET',"$api_base_url/$cloud_service/pca/$pca_service/sessions/$session_id_to_list/files/$file_in_session"));
				my $file_name=$file_in_session_properties->{'name'};
				my $file_state=$file_in_session_properties->{'state'};
				my $file_size=$file_in_session_properties->{'size'};
				my $file_type=$file_in_session_properties->{'type'};
				print "$file_name\tID=$file_in_session\tSize=$file_size\tType=$file_type\tState=$file_state\n";
			}
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
				my $session_size=sprintf "%.2f",$pca_session_properties->{'size'}/1073741824;
				my $session_state=$pca_session_properties->{'state'};
				print "Session $pca_session named $session_name ended on $session_end_date has a size of $session_size GB and is in state $session_state\n";
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
			my $pca_usage_in_KB=sprintf "%.0f",$pca_usage/1024;
			my $pca_usage_in_MB=sprintf "%.0f",$pca_usage_in_KB/1024;
			my $pca_usage_in_GB=sprintf "%.1f",$pca_usage_in_MB/1024;
			my $pca_usage_in_TB=sprintf "%.2f", $pca_usage_in_GB/1024;
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
			$timestamp=$timestamp-abs($timestampdifference);
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
	my $signaturepresha=$as.'+'.$ck.'+'.$method.'+'.$apiurl.'+'.$body.'+'.$timestamp;
	my $digest = sha_hex($signaturepresha);
	my $signature = '$1$'.$digest;
	return $signature;
}

sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
