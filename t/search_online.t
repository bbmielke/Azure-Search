use strict;
use warnings;
use Test::More;

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
my $test_index        = 'test3';
my $test_api_version  = '2017-11-11';

ok($test_service_name, "Extracted test_service_name from config");
ok($test_api_key,      "Extracted test_api_key from config");

my @test_documents1 = ({'name' => 'Brian', have_address => $JSON::PP::true});

my $azs = Azure::Search->new(service_name => $test_service_name, index => $test_index, api_version => $test_api_version, api_key => $test_api_key,);

is(ref $azs, 'Azure::Search', "Created Azure::Search object");

my $tx = $azs->search_documents('search' => '*', 'count' => $JSON::PP::true,);
ok($tx->success, "search_documents1 success check");
ok(!$tx->error,  "search_documents1 error check");
is($tx->result->code,                   200, "search_documents1 result code check");
is($tx->result->json->{'@odata.count'}, 0,   "search_documents1 count check");         # Count other than 0 means index probably already existed

$tx = $azs->search_documents('search' => '*', 'invalid_argument' => 'invalid',);
ok(!$tx->success, "search_documents2 success check");
ok($tx->error,    "search_documents2 error check");
is($tx->result->code, 400, "search_documents2 result code check");

$tx = $azs->upload_documents(@test_documents1);
ok($tx->success, "upload_documents1 success check");
ok(!$tx->error,  "upload_documents1 error check");
is($tx->result->code,                         200, "upload_documents1 result code check");
is($tx->result->json->{value}[0]{statusCode}, 201, "upload_documents1 value statusCode check");
sleep 1;    ## It seems to take a little bit of time for uploads to be reflected in following query

$tx = $azs->upload_documents(@test_documents1);
is($tx->result->json->{value}[0]{statusCode}, 200, "upload_documents1.1 second upload statusCode change check");
sleep 1;    ## It seems to take a little bit of time for uploads to be reflected in following query

$tx = $azs->search_documents('search' => '*', 'count' => $JSON::PP::true,);
ok($tx->success, "search_documents3 success check");
is($tx->result->json->{'@odata.count'},             scalar @test_documents1, "search_documents3 count check");
is($tx->result->json->{'value'}[0]{'have_address'}, $JSON::PP::true,         "search_documents3 value check");
is($tx->result->json->{'value'}[0]{'name'},         'Brian',                 "search_documents3 value check");

$tx = $azs->upload_documents();    ## No documents should cause error
ok(!$tx->success, "upload_documents2 success check");
ok($tx->error,    "upload_documents2 error check");

$tx         = $azs->merge_documents(@test_documents1);
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

done_testing();

