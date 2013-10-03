#!/usr/bin/perl
#use strict;
use LWP;

my $myAppKey = "XXXXXXXXXXXXXXXXXXX";
my $browser = LWP::UserAgent->new;
my $url = 'https://api.ovh.com/1.0/auth/credential';

# Issue request, with an HTTP header
my $response = $browser->post(
	$url,
  	'Content-type' => 'application/json',
  	'X-Ovh-Application' => $myAppKey,
  	'{ "accessRules": [ { "method": "GET", "path": "/*" }, {"method":"POST","path":"/*"}, {"method":"PUT","path":"/*"}, {"method":"DELETE","path":"/*"} ] }'
);
print $response;

die 'Error getting $url' unless $response->is_success;
print 'Content type is ', $response->content_type;
print 'Content is:';
print $response->content;