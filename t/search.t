use strict;
use warnings;
use Test::More;

use_ok('Mojolicious::Lite');
use_ok('Mojo::UserAgent');
use_ok('Azure::Search');

my $test_index       = 'index';
my $test_service_url = '/mojo_test';
my $test_api_version = '2017-11-11';
my $test_api_key     = 'testing123';

#
# This is a challenge to test effectively in a unit test setup since
# all the code really does is configures a few paths/arguments
# and passes them along to Mojo::UserAgent to call Azure's rest api.
# So let's setup a mockup mojolicious server to test against for a few
# tests with actual data extracted from querying the real windows
# azure rest api.
#

my $mock = Mojolicious::Lite->new;

$mock->routes->post("$test_service_url/indexes/:index/docs/search" => sub {
      my $c = shift;
      if ($c->req->json->{'invalid_argument'}) {
         return $c->render(
            status => 400,
            json   => {
               error => {
                  code => '',
                  message => "The request is invalid. Details: parameters : The parameter 'invalid_argument' in the request payload is not a valid parameter for the operation 'search'.\cM\cJ"
               }
            }
         );
      }
      return $c->render(
         status => 200,
         json   => {
            '@odata.count'   => 1,
            '@odata.context' => "$test_service_url/indexes(\'index\')/\$metadata#docs",
            values           => [{'@search.score' => 1, 'string' => 'abcdefghijklmnopqrstuvwyxz', 'double' => 3.14, 'boolean' => \1,}]
         }
      );
   }
);

# Leverage the mockup and run a couple of search queries

my $test_user_agent = Mojo::UserAgent->new();
is(ref $test_user_agent, 'Mojo::UserAgent', 'Created Mojo::UserAgent object');

$test_user_agent->server->app($mock);

my $azs = Azure::Search->new(
   service_url => $test_service_url,
   index       => $test_index,
   api_version => $test_api_version,
   api_key     => $test_api_key,
   user_agent  => $test_user_agent,
);

is(ref $azs, 'Azure::Search', "Created Azure::Search object");

my $tx = $azs->search_index('search' => '*', 'count' => \1,);

ok($tx->success, "Successful response from normal search query");
ok(!$tx->error,  "No error from normal search query");
is($tx->result->json->{'@odata.count'}, 1, "Got a count of 1 in the result");
is($tx->result->json->{'values'}[0]{'boolean'}, $JSON::PP::true, "Got a true response in the data for the boolean field");

$tx = $azs->search_index('search' => '*', 'invalid_argument' => 'invalid',);

ok(!$tx->success, "Did not get a successful response with an invalid argument");
ok($tx->error,    "Got an error as expected");
is($tx->result->code, 400);

done_testing();

