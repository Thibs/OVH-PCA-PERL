#! /usr/bin/perl -w
# Written by Thibault Richard. http://hosting.thibs.com
# The following code is released under the terms of either the GNU
# General Public License or the Artistic License
# http://www.opensource.org/licenses/artistic-license-2.0.php
# http://www.gnu.org/licenses/gpl-3.0.txt

use warnings;
use strict;
use LWP::UserAgent;
use JSON qw( decode_json );
use HTTP::Date;
use Digest::SHA1 qw(sha1 sha1_hex);
use Getopt::Std;

#Change your settings here
my $as='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'; #Put here your  application secret
my $ck='YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY'; #Put here your consumer key
my $ak='ZZZZZZZZZZZZZZZZ'; # Put here your application key
my $api_base_url='https://api.ovh.com/1.0/cloud';

#Do not change after this line unless you really knows what you're doing
sub usage();
sub deletesession($);
sub rename_last_session($);

my $ua = LWP::UserAgent->new;
$ua->agent("Thibs-OVH-API/0.1 ");

my %opt=();
getopts("d:r:h",\%opt) or usage();
usage() if $opt{h};
my $pca_session_max_age = $opt{d};
my $pca_session_newname = $opt{r};

if ((defined($pca_session_max_age))||(defined($pca_session_newname))) {
	if (defined($pca_session_max_age)) {
		if ($pca_session_max_age !~ /\d+/ ) {
			$pca_session_max_age='86400'; # Exprimed in seconds ; 1 day is 86400 seconds
		}
		deletesession($pca_session_max_age);
	}
	if (defined($pca_session_newname)) {
		rename_last_session($pca_session_newname);
	}
}
else {
	usage();
}
exit(0);

# Functions
sub error($);
sub GetOVHtimestamp();
sub CallOVHapi($$$$;$);
sub GetOVHSignature($$$$$;$);

sub usage()
{
  print STDERR << "EOF";
  Multi purpose command line utility on OVH PCA api 

  usage: $0 [-d] max_session_age_in_seconds | [-r] new_name

   -h : this (help) message
   -d : delete PCA session older than X
   -r : Rename last PCA session into Y

  example: perl $0 -d 86400 (=delete session older than a day)
           perl $0 -r session_name (=rename last session into session_name)

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
			print "Session $last_session has been renamed into $pca_session_newname";
		}
	}
}

sub deletesession ($) {
	$pca_session_max_age=$_[0];
	my $ua = LWP::UserAgent->new;
	my $timestamp = time;
	$ua->agent("Thibs-OVH-API/0.1 ");
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
	my $timestamp = time; #Fall back to local time if OVH is not answering
	# Get OVH timestamp
	my $req = HTTP::Request->new(GET => 'https://api.ovh.com/1.0/auth/time');
	my $res = $ua->request($req);
	if ($res->is_success) {
		$timestamp=$res->content;
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