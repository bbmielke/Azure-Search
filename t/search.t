use strict;
use warnings;
use Test::More;

use_ok('Mojolicious::Lite');
use_ok('Mojo::UserAgent');
use_ok('Azure::Search');
use_ok('JSON::PP');

my $test_index       = 'index';
my $test_service_url = '/mojo_test';
my $test_api_version = '2017-11-11';
my $test_api_key     = 'testing123';

my @test_documents1 = ({'name' => 'Brian', have_address => $JSON::PP::true});

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
                value => [{'@search.score' => 1, 'string' => 'abcdefghijklmnopqrstuvwyxz', 'double' => 3.14, 'boolean' => $JSON::PP::true,}]
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
            && $c->req->json->{'value'}[0]{'@search.action'} =~ /^(merge|delete)$/)
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
                value            => [{errorMessage => undef, key => 'Brian', status => $JSON::PP::true, statusCode => $statusCode}]
            }
        );
    }
);

$mock->routes->post(
    "$test_service_url/indexes" => sub {
        my $c = shift;
        return $c->render(status => 201, json => {});
    },
);

$mock->routes->put(
    "$test_service_url/indexes/:index" => sub {
        my $c = shift;
        return $c->render(status => 204, json => {});
    },
);

$mock->routes->delete(
    "$test_service_url/indexes/:index" => sub {
        my $c = shift;
        return $c->render(status => 204, json => {});
    },
);

$mock->routes->get(
    "$test_service_url/indexes/:index" => sub {
        my $c = shift;
        return $c->render(status => 200, json => {});
    },
);

$mock->routes->get(
    "$test_service_url/indexes/" => sub {
        my $c = shift;
        return $c->render(status => 200, json => {});
    },
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

my $tx;
my $error;
my $results;

$tx = $azs->create_index({'key' => $JSON::PP::true, 'name' => 'name', 'type' => 'Edm.String'});
is($tx->result->code, 201, 'create_index1 mocked test');

$tx = $azs->update_index({'key' => $JSON::PP::true, 'name' => 'name', 'type' => 'Edm.String'});
is($tx->result->code, 204, 'update_index1 mocked test');

$tx = $azs->get_index({'key' => $JSON::PP::true, 'name' => 'name', 'type' => 'Edm.String'});
is($tx->result->code, 200, 'get_index1 mocked test');

$tx = $azs->get_indexes({'key' => $JSON::PP::true, 'name' => 'name', 'type' => 'Edm.String'});
is($tx->result->code, 200, 'get_indexes1 mocked test');

$tx = $azs->delete_index({'key' => $JSON::PP::true, 'name' => 'name', 'type' => 'Edm.String'});
is($tx->result->code, 204, 'delete_index mocked test');

($error, $results) = $azs->search_documents('search' => '*', 'count' => $JSON::PP::true,);
ok(!$error, "search_documents1 error check");
is($results->{'@odata.count'}, 1, "search_documents1 count check");
is($results->{'value'}[0]{'boolean'}, $JSON::PP::true, "search_documents1 value check");

($error, $results) = $azs->search_documents('search' => '*', 'invalid_argument' => 'invalid',);
ok($error, "search_documents2 returned an error");

($error, $results) = $azs->upload_documents(@test_documents1);
ok(!$error,  "upload_documents1 error check");
is($results->{value}[0]{statusCode}, 201, "upload_documents1 value statusCode check");

($error, $results) = $azs->upload_documents();
ok($error,    "upload_documents2 error check");

($error, $results) = $azs->merge_documents(@test_documents1);
ok(!$error, "merge_documents1 error check");
is($results->{value}[0]{statusCode}, 200, "merge_documents1 value statusCode check");

($error, $results) = $azs->merge_or_upload_documents(@test_documents1);
ok(!$error, "merge_or_upload_documents1 error check");
is($results->{value}[0]{statusCode}, 201, "merge_or_upload_documents1 value statusCode check");

($error, $results) = $azs->delete_documents(@test_documents1);
ok(!$error, "delete_documents1 error check");
is($results->{value}[0]{statusCode}, 200, "delete_documents1 value statusCode check");

done_testing();

