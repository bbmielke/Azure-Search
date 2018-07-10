use strict;
use warnings;
use Test::More;
use utf8;

plan skip_all => 'set TEST_ONLINE_YML to a properly configured test_online.yml file to enable' if (!$ENV{TEST_ONLINE_YML});

=pod

If you wish to use TEST_ONLINE export TEST_ONLINE=/path/to/test_online.yml (or any other name),
the contents of the yml file must include:

service_name: <name of search service that you created in azure>
api_key: <api key for this azure service>

These tests will create an index and delete them as named below in $test_index.
The online tests will run with test_api_version of 2017-11-11.

=cut

use_ok('Azure::Search');
use_ok('JSON::PP');
use_ok('YAML');

my $config = YAML::LoadFile($ENV{TEST_ONLINE_YML});
ok($config, "Parsed config");

my $test_service_name = $config->{service_name};
my $test_api_key      = $config->{api_key};
my $test_index        = 'searchonlinetest';
my $test_api_version  = '2017-11-11';

my @test_fields = (
    {
        name        => 'name',
        type        => 'Edm.String',
        key         => $JSON::PP::true,
        searchable  => $JSON::PP::true,
        filterable  => $JSON::PP::true,
        retrievable => $JSON::PP::true,
    },
    {
        name        => 'age',
        type        => 'Edm.Int32',
        key         => $JSON::PP::false,
        searchable  => $JSON::PP::false,
        filterable  => $JSON::PP::true,
        retrievable => $JSON::PP::true,
    },
    {
        name        => 'have_address',
        type        => 'Edm.Boolean',
        key         => $JSON::PP::false,
        searchable  => $JSON::PP::false,
        filterable  => $JSON::PP::true,
        retrievable => $JSON::PP::true,
    },
    {
        name        => 'date',
        type        => 'Edm.DateTimeOffset',
        key         => $JSON::PP::false,
        searchable  => $JSON::PP::false,
        filterable  => $JSON::PP::true,
        retrievable => $JSON::PP::true,
    },
    {name => 'name2', type => 'Edm.String',},
);

ok($test_service_name, "Extracted test_service_name from config");
ok($test_api_key,      "Extracted test_api_key from config");

my $error;
my $tx;
my $results;

my @test_documents1 = ({'name' => 'Brian', have_address => $JSON::PP::true, name2 => 'Brian Müller'});

my $azs = Azure::Search->new(service_name => $test_service_name, index => $test_index, api_version => $test_api_version, api_key => $test_api_key,);

is(ref $azs, 'Azure::Search', "Created Azure::Search object");

$tx = $azs->create_index(@test_fields);

ok($tx->success, "create_index1 success check");
ok(!$tx->error,  "create_index1 error check");
is($tx->result->code, 201, "create_index1 status code");
sleep 1;

$tx = $azs->update_index(@test_fields);
ok($tx->success, "update_index1 success check");
ok(!$tx->error,  "update_index1 error check");
is($tx->result->code, 204, "update_index1 status code");
sleep 1;

$tx = $azs->get_index();
ok($tx->success, "get_index1 success check");
is($tx->result->code,         200,         "get_index1 status code");
is($tx->result->json->{name}, $test_index, "get_index1 name check");

$tx = $azs->get_indexes();
ok($tx->success, "get_indexes1 success check");
is($tx->result->code, 200, "get_indexes1 status code");
ok($tx->result->json->{value}[0]{name}, "get_indexes1 name is there check");

($error, $results) = $azs->search_documents('search' => '*', 'count' => $JSON::PP::true,);
ok(!$error, "search_documents1 error check");
is($results->{'@odata.count'}, 0, "search_documents1 count check");    # Count other than 0 means index probably already existed

($error, $results) = $azs->search_documents('search' => '*', 'invalid_argument' => 'invalid',);
ok($error, "search_documents2 error check");

$tx = $azs->upload_documents(@test_documents1);
ok($tx->success, "upload_documents1 success check");
ok(!$tx->error,  "upload_documents1 error check");
is($tx->result->code,                         200, "upload_documents1 result code check");
is($tx->result->json->{value}[0]{statusCode}, 201, "upload_documents1 value statusCode check");
sleep 1;    ## It seems to take a little bit of time for uploads to be reflected in following query

$tx = $azs->upload_documents(@test_documents1);
is($tx->result->json->{value}[0]{statusCode}, 200, "upload_documents1.1 second upload statusCode change check");
sleep 1;    ## It seems to take a little bit of time for uploads to be reflected in following query

($error, $results) = $azs->search_documents('search' => '*', 'count' => $JSON::PP::true,);
ok(!$error, "search_documents3 success check");
is($results->{'@odata.count'},             scalar @test_documents1, "search_documents3 count check");
is($results->{'value'}[0]{'have_address'}, $JSON::PP::true,         "search_documents3 value check");

# The next check also checks utf8 issues between communication with the server and back
is($results->{'value'}[0]{'name2'}, 'Brian Müller', "search_documents3 value check");

$tx = $azs->upload_documents();    ## No documents should cause error
ok(!$tx->success, "upload_documents2 success check");
ok($tx->error,    "upload_documents2 error check");

$tx = $azs->merge_documents(@test_documents1);
ok($tx->success, "merge_documents1 sucess check");
is($tx->result->code,                         200, "merge_documents1 result code check");
is($tx->result->json->{value}[0]{statusCode}, 200, "merge_documents1 value statusCode check");

$tx = $azs->delete_documents(@test_documents1);
ok($tx->success, "delete_documents1 success check");
sleep 1;

# Now merge documents should fail with a 207 and 404 error
$tx = $azs->merge_documents(@test_documents1);
is($tx->result->code,                         207, "merge_documents1 result code check");
is($tx->result->json->{value}[0]{statusCode}, 404, "merge_documents1 value statusCode check");
sleep 1;

$tx = $azs->merge_or_upload_documents(@test_documents1);
ok($tx->success, "merge_or_upload_documents1 sucess check");
is($tx->result->code,                         200, "merge_or_upload_documents1 result code check");
is($tx->result->json->{value}[0]{statusCode}, 201, "merge_or_upload_documents1 value statusCode check");
sleep 1;

$tx = $azs->delete_documents(@test_documents1);
ok($tx->success, "delete_documents2 success check");
sleep 1;

$tx = $azs->delete_index();
ok($tx->success, "delete_index1 success check");
is($tx->result->code, 204, "delete_index1 status code");

done_testing();

