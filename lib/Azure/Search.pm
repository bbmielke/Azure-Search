package Azure::Search;

use Mojo::Base -strict;
use Mojo::UserAgent;

our $VERSION = '0.02';

sub new {
    my ($class, %args) = @_;
    my $this = {};
    bless $this, $class;
    $this->_init(%args);
    return $this;
}

sub _init {
    my ($self, %args) = @_;

    if (defined $args{'service_url'}) {
        $self->{'service_url'} = $args{'service_url'};
    }
    elsif (defined $args{'service_name'}) {
        die "service_name argument appears to be a url" if ($args{service_name} =~ /^https?:/i);
        $self->{'service_url'} = "https://$args{service_name}.search.windows.net";
    }
    else {
        die "Either service_name or service_url are required with Azure::Search";
    }

    my @required_args = qw(index api_version api_key);
    for my $arg (@required_args) {
        $self->{$arg} = $args{$arg} // die "$arg is required with Azure::Search";
    }

    if ($args{user_agent}) {
        $self->{user_agent} = $args{user_agent};
    }
    else {
        $self->{user_agent} = Mojo::UserAgent->new();
    }
}

sub search_documents {
    my ($self, %args) = @_;
    my $url = "$self->{service_url}/indexes/$self->{index}/docs/search?api-version=$self->{api_version}";
    my $tx = $self->{user_agent}->post($url => {'api-key' => $self->{api_key}} => json => \%args);
    if (!$tx->success) {
        my $code    = $tx->error->{code};
        my $message = $tx->error->{message};
        my $body    = $tx->result->body;
        return ("$code: $message: $body", $tx->result->json);
    }
    elsif ($tx->result->code != 200) {
        return ("Unexpected status code: " . $tx->result->code, $tx->result->json);
    }
    else {
        return (undef, $tx->result->json);
    }
}

sub upload_documents {
    my ($self, @documents) = @_;
    return $self->_cud_documents('upload', @documents);
}

sub merge_documents {
    my ($self, @documents) = @_;
    return $self->_cud_documents('merge', @documents);
}

sub merge_or_upload_documents {
    my ($self, @documents) = @_;
    return $self->_cud_documents('mergeOrUpload', @documents);
}

sub delete_documents {
    my ($self, @documents) = @_;
    return $self->_cud_documents('delete', @documents);
}

##
## CUD -> create, update, delete, (upsert too), but not read.  Read is handled by search_documents.
##
sub _cud_documents {
    my ($self, $action, @documents) = @_;
    for my $document (@documents) {
        $document->{'@search.action'} = $action;
    }
    my $url = "$self->{service_url}/indexes/$self->{index}/docs/index?api-version=$self->{api_version}";
    return $self->{user_agent}->post($url => {'api-key' => $self->{api_key}} => json => {value => \@documents});
}

sub create_index {
    my ($self, @fields) = @_;
    my $url = "$self->{service_url}/indexes?api-version=$self->{api_version}";
    return $self->{user_agent}->post($url => {'api-key' => $self->{api_key}} => json => {name => $self->{index}, fields => \@fields});
}

sub update_index {
    my ($self, @fields) = @_;
    my $url = "$self->{service_url}/indexes/$self->{index}?api-version=$self->{api_version}";
    return $self->{user_agent}->put($url => {'api-key' => $self->{api_key}} => json => {name => $self->{index}, fields => \@fields});
}

sub delete_index {
    my ($self) = @_;
    my $url = "$self->{service_url}/indexes/$self->{index}?api-version=$self->{api_version}";
    return $self->{user_agent}->delete($url => {'api-key' => $self->{api_key}});
}

sub get_index {
    my ($self) = @_;
    my $url = "$self->{service_url}/indexes/$self->{index}?api-version=$self->{api_version}";
    return $self->{user_agent}->get($url => {'api-key' => $self->{api_key}});
}

sub get_indexes {
    my ($self) = @_;
    my $url = "$self->{service_url}/indexes?api-version=$self->{api_version}";
    return $self->{user_agent}->get($url => {'api-key' => $self->{api_key}});
}

1;

=head1 NAME

Azure::Search - Perl interacting with Azure Search's REST API.

=head1 SYNOPSIS

    use Azure::Search;

    my $azs = Azure::Search->new(
        service_name => '<azure_search_service_name>',
        api_version  => '2017-11-11',
        index        => '<index_name>',
        api_key      => '<api_key>',
    );

    my $tx = $azs->search_documents(
        search      => '*',
        count       => \1,
        top         => 1,
    );

    ## Parse rest response as you would with other Mojo::Transaction::HTTP object
    ## See EXAMPLES below for more details.

=head1 DESCRIPTION

Leverage L<Mojo::UserAgent> to interact with Azure Search's REST api.

=over

=item new(%args)

Create an Azure::Search object.

Required args:

api_version - So far I've been testing with '2017-11-11' of Azure Search's API
api_key     - api key for your azure search instance
index       - index name you wish to operate with

One of these options are required:

service_name - Name of the service for your search api.
service_url  - URL to your search service

Optional:

user_agent - your own Mojo::UserAgent object (useful for mockups/testing)

=item search_documents(%args)

This will run a query on your $azs object to query your search index with %args passed
along to the rest api.

This method returns an error string (or undef) and a hash representing the json response
returned by Azure::Search.  You should check for the error string after each call.

I will provide some examples below, but for a full list of
options please go to:

L<https://docs.microsoft.com/en-us/rest/api/searchservice/search-documents>

=item upload_documents(@documents)

Upload an array of hash ref documents to the index.  This replaces the document
if it already exists in the index.

For more information on upload, merge_or_upload, or delete look at:

L<https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents>

=item merge_documents(@documents)

Merge documents onto the index.  This fails if the document does not already exist
in the index, and it merges the hash keys.

Merge documents can return a success on $tx->success, while still having errors on individual documents.
You should loop through each document to see each documents status.  See the EXAMPLE below (or review search_online.t for example)

For more information on upload, merge_or_upload, or delete look at:

L<https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents>

=item merge_or_upload_documents(@documents)

Merge or upload documents onto the index.  It does not overwrite and it does create if needed.
This method is more forgiving than merge in the situation where a document does not exist in
the index yet, so you do not have to loop through the status of each individual document
being merge_or_uploaded.

For more information on upload, merge_or_upload, or delete look at:

L<https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents>

=item delete_documents(@documents)

Delete documents from the index -- not individual fields. The microsoft documentation states
to delete a field use merge instead, and submit the document with a null (undef in perl)
value for the field you wish to delete.

For more information on upload, merge_or_upload, or delete look at:

L<https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents>

=item create_index(@fields)

Create an index for @fields.  There are a lot of field options.  Please look at the microsoft site
for complete details.  I'll have an example of one below.

L<https://docs.microsoft.com/en-us/rest/api/searchservice/create-index>

Please note the rules on the 'key' field.  They can't be utf8 but other string fields can be.

=item update_index(@fields)

Update an index for @fields.  This is a very finicky operation.  It does not seem to allow you to
change fields from searchable => false to true, but it does allow you to add new fields to the
index.

L<https://docs.microsoft.com/en-us/rest/api/searchservice/update-index>

=item delete_index

Delete the index.

=item get_index

Return details on the index.

=item get_indexes

Return details on all indexes.

=back

=head1 EXAMPLES

    Search for anything and grab the first value and a count of matches.

    my ($error,$result) = $azs->search_documents(
        search      => '*',
        count       => \1,
        top         => 1,
    );

    if ($error) {
        warn "Error searching_documents: $error";
    }
    else {
        say "NUMBER OF RESULTS: " . $results->{'@odata.count'};
        say "DUMP OF RESULTS: " . Dumper($results);
    }

    Search the index by the name field, where the name is not Brian.
    Filter the results further for non-Brians who have an address
    and a date lt 2018-06-26. Please note boolean and date fields
    can not be searched directly, but they can be filtered.

    my($error, $results) = $azs->search_documents(
        search    => '-name:Brian',
        top       => 100,
        queryType => 'full',
        count     => \1,
        select    => 'name',
        filter    => 'date lt 2018-06-26 AND have_address eq true',
    );

    Upload documents to the search index.

    my $tx = $azs->upload_documents(
        {
            name => 'Brian1',
            date => DateTime->now->iso8601 . 'Z',
            have_address => \1,
        },
        {
            name => 'Brian2',
            date => DateTime->now->iso8601 . 'Z',
            have_address => \0,
        },
    );

    Review $tx for upload_documents errors:

    if (!$tx->success) {
        my $code = $tx->error->{code};
        my $message = $tx->error->{message};
        my $body = $tx->result->body;
        warn "Azure Search Call returned: $code: $message: $body";
    }

    #Modify existing documents with new hash entries:

    my $tx = $azs->merge_documents({'name' => 'does not exist yet', have_address=>\0}, {'name' => 'Brian', have_address => \0});

    # Review $tx for merge_documents errors:

    if (!$tx->success) {
        my $code = $tx->error->{code};
        my $message = $tx->error->{message};
        my $body = $tx->result->body;
        warn "Azure Search Call returned: $code: $message: $body";
    }
    else {
        for my $document (@{$tx->result->json->{value}}) {
            if($document->{'statusCode'} != 200) {
                warn "Document uploaded with unexpected statusCode - $document->{'key'}: $document->{statusCode}: $document->{errorMessage}";
            }
        }
    }

    Upload documents without overwriting all old hash entries with merge_or_upload:

    my $tx = $azs->merge_or_upload_documents({'name' => 'does not exist yet', have_address=>\0}, {'name' => 'Brian', have_address => \0});

    This method is more forgiving than merge_documents, so you do not have to loop through each individual document to check the status, but you can if you wish.

    Create an index with a variety (but not a complete slice) of the available options:

    my $tx = $azs->create_index(
        {
            name => 'name',
            type => 'Edm.String',
            key => $JSON::PP::true,
            searchable => $JSON::PP::true,
            filterable => $JSON::PP::true,
            retrievable => $JSON::PP::true,
        },
        {
            name => 'age',
            type => 'Edm.Int32',
            key => $JSON::PP::false,
            searchable => $JSON::PP::false,
            filterable => $JSON::PP::true,
            retrievable => $JSON::PP::true,
        },
        {
            name => 'have_address',
            type => 'Edm.Boolean',
            key => $JSON::PP::false,
            searchable => $JSON::PP::false,
            filterable => $JSON::PP::true,
            retrievable => $JSON::PP::true,
        },
        {
            name => 'date',
            type => 'Edm.DateTimeOffset',
            key => $JSON::PP::false,
            searchable => $JSON::PP::false,
            filterable => $JSON::PP::true,
            retrievable => $JSON::PP::true,
        },
    );

    die "Error creating index" if(!$tx->success || $tx->result->code != 201);

    # Update index works similarily as the call above but you check for != 204 in the response code

=cut
