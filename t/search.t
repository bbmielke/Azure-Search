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

my @test_documents1 = ({'name' => 'Brian', have_address => \1});

##
## This is a challenge to test effectively in a unit test setup since
## all the code really does is configures a few paths/arguments
## and passes them along to Mojo::UserAgent to call Azure's rest api.
## So let's setup a mockup mojolicious server to test against for a few
## tests with actual data extracted from querying the real windows
## azure rest api.
##

my $mock = Mojolicious::Lite->new;

$mock->routes->post(
    "$test_service_url/indexes/:index/docs/search" => sub {
        my $c = shift;
        if ($c->req->json->{'invalid_argument'}) {
            return $c->render(
                status => 400,
                json   => {
                    error => {
                        code => '',
                        message =>
                            "The request is invalid. Details: parameters : The parameter 'invalid_argument' in the request payload is not a valid parameter for the operation 'search'.\cM\cJ"
                    }
                }
            );
        }
        return $c->render(
            status => 200,
            json   => {
                '@odata.count'   => 1,
                '@odata.context' => "$test_service_url/indexes('index')/\$metadata#docs",
                values           => [{'@search.score' => 1, 'string' => 'abcdefghijklmnopqrstuvwyxz', 'double' => 3.14, 'boolean' => \1,}]
            }
        );
    },
);
$mock->routes->post(
    "$test_service_url/indexes/:index/docs/index" => sub {
        my $c          = shift;
        my $statusCode = 201;
        if (   defined $c->req->json
            && defined $c->req->json->{'value'}
            && $c->req->json->{'value'}[0]
            && $c->req->json->{'value'}[0]{'@search.action'} =~ /^(merge|delete)/)
        {
            $statusCode = 200;
        }
        if (!@{$c->req->json->{'value'}}) {
            return $c->render(
                status => 400,
                json   => {
                    error => {
                        code => '',
                        message =>
                            "The request is invalid. Details: actions : No indexing actions found in the request. Please include between 1 and 1000 indexing actions in your request.\cM\cJ"
                    }
                }
            );
        }
        return $c->render(
            status => 200,
            json   => {
                '@odata.context' => "$test_service_url/indexes('index')/\$metadata#Collection(Microsoft.Azure.Search.V2017_11_11.IndexResult)",
                values           => [{errorMessage => undef, key => 'Brian', status => \1, statusCode => $statusCode}]
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

my $tx = $azs->search_documents('search' => '*', 'count' => \1,);
ok($tx->success, "search_documents1 success check");
ok(!$tx->error,  "search_documents1 error check");
is($tx->result->code,                           200,             "search_documents1 result code check");
is($tx->result->json->{'@odata.count'},         1,               "search_documents1 count check");
is($tx->result->json->{'values'}[0]{'boolean'}, $JSON::PP::true, "search_documents1 values check");

$tx = $azs->search_documents('search' => '*', 'invalid_argument' => 'invalid',);
ok(!$tx->success, "search_documents2 success check");
ok($tx->error,    "search_documents2 error check");
is($tx->result->code, 400, "search_documents2 result code check");

$tx = $azs->upload_documents(@test_documents1);
ok($tx->success, "upload_documents1 success check");
ok(!$tx->error,  "upload_documents1 error check");
is($tx->result->code,                          200, "upload_documents1 result code check");
is($tx->result->json->{values}[0]{statusCode}, 201, "upload_documents1 value statusCode check");

$tx = $azs->upload_documents();
ok(!$tx->success, "upload_documents2 success check");
ok($tx->error,    "upload_documents2 error check");

$tx = $azs->merge_documents(@test_documents1);
ok($tx->success, "merge_documents1 sucess check");
is($tx->result->code,                          200, "merge_documents1 result code check");
is($tx->result->json->{values}[0]{statusCode}, 200, "merge_documents1 value statusCode check");

$tx = $azs->merge_or_upload_documents(@test_documents1);
ok($tx->success, "merge_or_upload_documents1 sucess check");
is($tx->result->code,                          200, "merge_or_upload_documents1 result code check");
is($tx->result->json->{values}[0]{statusCode}, 200, "merge_or_upload_documents1 value statusCode check");

$tx = $azs->delete_documents(@test_documents1);
ok($tx->success, "delete_documents1 sucess check");
is($tx->result->code,                          200, "delete_documents1 result code check");
is($tx->result->json->{values}[0]{statusCode}, 200, "delete_documents1 value statusCode check");

done_testing();

