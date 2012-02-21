#!/usr/bin/perl

use strict;
use warnings;

use URI::Escape qw/ uri_escape /;
use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;
use Data::Dumper;
use CGI;
use Template;

use constant {
    CONSUMER_KEY    => '',
    CONSUMER_SECRET => '',
    REDIRECT_URI    => 'http://adsdev.symbio.inmobi-jp.com/katsu/mixi_graph/state.pl',

    MIXI_TOKEN_ENDPOINT => 'https://secure.mixi-platform.com/2/token',
    MIXI_API_ENDPOINT   => 'http://api.mixi-platform.com/2'
};

my $debug = 0;
#main
{
  my $query = CGIinit();

  #TestTemplate();
  StateTT($query);
}

sub CGIinit{
  my $query = new CGI;
  print $query->header(-type=>'text/html; charset=utf-8');

  my @params = $query->param();
  my $q = {};

  if(!@params){
    $q = {state => 1};
  }elsif($query->param('state') == 1){

  }elsif($query->param('state') == 2){
    $q = {state => 2};
  }elsif($query->param('state') == 3){

  }elsif($query->param('state') == 4){
    $q = {state => 4, code => $query->param('code')};
  }elsif($query->param('state') == 5){
    my $auth_code = $query->param('code');
    my $token = GetToken($auth_code);
    $q = {state => 5, code => $auth_code, token => $token};
  }elsif($query->param('state') == 6){
    my $token = {access_token  => $query->param('atoken'), refresh_token => $query->param('rtoken')};
    #my $endpoint = '/people/@me/@self';
    my $endpoint = '/voice/statuses/@me/user_timeline';
    #my $endpoint = '/people/@me/@selfAuthorization';
    my $json_href = MixiCall($endpoint, $token);
    my $url = MIXI_API_ENDPOINT . $endpoint . '?oauth_token=' . uri_escape($token->{'access_token'});
    $q = {state => 6, url => $url, res => $json_href, token => $token};
  }elsif($query->param('state') == 7){

  }

  if($debug){
    foreach(@params){
      print "[Params]key:",$_, "\t","value:",$query->param($_), "<br>";
    }
    print Dumper $q;
  }
  return $q;
}

sub StateTT{
  my $q = shift;
  my $tt = new Template;
  my $out;

  my $res = Dumper $q->{res};
  my $token = Dumper $q->{token};

  my $vars = {
    state  => $q->{state},
    code   => $q->{code},
    atoken => $q->{token}->{access_token},
    rtoken => $q->{token}->{refresh_token},
    url    => $q->{url},
    res    => $res,
    token  => $token,
  };

  $tt->process('state.tt', $vars, $out) or die $tt->error;
  print $out;
}

sub request {
    my ($method, $url, $data_arr) = @_;
    my $req = HTTP::Request->new(
        $method => $url
    );

    if ($method eq 'POST') {
        my $data_str = join '&', map { uri_escape($_) . '=' . uri_escape($data_arr->{$_}) } keys %$data_arr;
        $req->content_type('application/x-www-form-urlencoded');
        $req->content($data_str);
    }

    my $ua = LWP::UserAgent->new();
    my $res = $ua->request($req);

    return $res;
}

sub GetToken {
    my $auth_code = shift;

    my %data_arr = (
        'grant_type'    => 'authorization_code',
        'client_id'     => CONSUMER_KEY,
        'client_secret' => CONSUMER_SECRET,
        'code'          => $auth_code,
        'redirect_uri'  => REDIRECT_URI,
    );

    my $res = request('POST', MIXI_TOKEN_ENDPOINT, \%data_arr);
    die 'Request failed. ' . $res->status_line unless $res->is_success;

    return decode_json($res->content);
}

sub GetNewToken {
    my $refresh_token = shift;

    my %data_arr = (
        'grant_type'    => 'refresh_token',
        'client_id'     => CONSUMER_KEY,
        'client_secret' => CONSUMER_SECRET,
        'refresh_token' => $refresh_token,
    );

    my $res = request('POST', MIXI_TOKEN_ENDPOINT, \%data_arr);
    die 'Request failed. ' . $res->status_line unless $res->is_success;

    return decode_json($res->content);
}

sub MixiCall {
    my ($endpoint, $token) = @_;

    my $url = MIXI_API_ENDPOINT . $endpoint . '?oauth_token=' . uri_escape($token->{'access_token'});
    my $res = request('GET', $url);

    if (defined $res->header('WWW-Authenticate')) {
        my $error_msg = $res->header('WWW-Authenticate');

        if ($error_msg =~ /invalid_request/) {
            die 'Invalid request.';
        } elsif ($error_msg =~ /invalid_token/) {
            die 'Invalid token.';
        } elsif ($error_msg =~ /expired_token/) {
            $token = GetNewToken($token->{'refresh_token'});
            $url = MIXI_API_ENDPOINT . $endpoint . '?oauth_token=' . uri_escape($token->{'access_token'});
            return decode_json(request('GET', $url)->{'_content'});
        } elsif ($error_msg =~ /insufficient_scope/) {
            die 'Insufficient scope.';
        }
    }

    return decode_json($res->content);
}

sub TestTemplate{
  my $tt = new Template;

  my $vars = {
    name => 'とみた',
    hatena => 'tomi-ru',
    skill => ['迷子', '寝坊'],
    favorite => {
      game => 'ドラクエ３',
      movie => 'インディペンデンスデイ',
    },
    hello => sub {
      my $word = shift;
      return "こんにちは $word。";
    },
  };

  $tt->process('test.tt', $vars, my $out) or die $tt->error;

  print $out;
}
1;
