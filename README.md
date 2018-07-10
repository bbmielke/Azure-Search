# NAME

Azure::Search

# VERSION

version 0.02

# SYNOPSIS

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

# DESCRIPTION

Leverage [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) to interact with Azure Search's REST api.

- new(%args)

    Create an Azure::Search object.

    Required args:

    api\_version - So far I've been testing with '2017-11-11' of Azure Search's API
    api\_key     - api key for your azure search instance
    index       - index name you wish to operate with

    One of these options are required:

    service\_name - Name of the service for your search api.
    service\_url  - URL to your search service

    Optional:

    user\_agent - your own Mojo::UserAgent object (useful for mockups/testing)

- search\_documents(%args)

    This will run a query on your $azs object to query your search index with %args passed
    along to the rest api.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    I will provide some examples below, but for a full list of
    options please go to:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/search-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/search-documents)

- upload\_documents(@documents)

    Upload an array of hash ref documents to the index.  This replaces the document
    if it already exists in the index.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    Please note that each individual document gets a status code too that can be checked,
    but it's mostly unnecessary to check it unless calling merge\_documents.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- merge\_documents(@documents)

    Merge documents onto the index.  This fails if the document does not already exist
    in the index, and it merges the hash keys.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    In addition to checking the error on the call, merge returns a status for each
    document merged.  This is since individual documents may not exist and hence
    cant be merged.  You may want to check the status for each documents errors.
    Please look at the example below or review search\_online.t for an example.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- merge\_or\_upload\_documents(@documents)

    Merge or upload documents onto the index.  It does not overwrite and it does create if needed.
    This method is more forgiving than merge in the situation where a document does not exist in
    the index yet, so you do not have to loop through the status of each individual document
    being merge\_or\_uploaded.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    Please note that each individual document gets a status code too that can be checked,
    but it's mostly unnecessary to check it unless calling merge\_documents.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- delete\_documents(@documents)

    Delete documents from the index -- not individual fields. The microsoft documentation states
    to delete a field use merge instead, and submit the document with a null (undef in perl)
    value for the field you wish to delete.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- create\_index(@fields)

    Create an index for @fields.  There are a lot of field options.  Please look at the microsoft site
    for complete details.  I'll have an example of one below.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    [https://docs.microsoft.com/en-us/rest/api/searchservice/create-index](https://docs.microsoft.com/en-us/rest/api/searchservice/create-index)

    Please note the rules on the 'key' field.  They can't be utf8 but other string fields can be.

- update\_index(@fields)

    Update an index for @fields.  This is a very finicky operation.  It does not seem to allow you to
    change fields from searchable => false to true, but it does allow you to add new fields to the
    index.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

    [https://docs.microsoft.com/en-us/rest/api/searchservice/update-index](https://docs.microsoft.com/en-us/rest/api/searchservice/update-index)

- delete\_index

    Delete the index.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

- get\_index

    Return details on the index.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

- get\_indexes

    Return details on all indexes.

    This method returns an error string (or undef) and a hash representing the json response
    returned by Azure.  You should check for the error string after each call.

# NAME

Azure::Search - Perl interacting with Azure Search's REST API.

# EXAMPLES

    Search for anything and grab the first value and a count of matches.

    my ($error,$result) = $azs->search_documents(
        search      => '*',
        count       => \1,
        top         => 1,
    );

    if ($error) {
        die "Error searching_documents: $error";
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

    my ($error, $results) = $azs->upload_documents(
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

    if ($error) {
        die "Error upload_documents: $error";
    }

    #Modify existing documents with new hash entries:

    my($error, $results) = $azs->merge_documents({'name' => 'does not exist yet', have_address=>\0}, {'name' => 'Brian', have_address => \0});

    # Review errors:

    if ($error) {
        die "Error merge_documents: $error";
    }
    else {
        for my $document (@{$results}) {
            if($document->{'statusCode'} != 200) {
                warn "Document uploaded with unexpected statusCode - $document->{'key'}: $document->{statusCode}: $document->{errorMessage}";
            }
        }
    }

    Upload documents without overwriting all old hash entries with merge_or_upload:

    my($error,$results) = $azs->merge_or_upload_documents({'name' => 'does not exist yet', have_address=>\0}, {'name' => 'Brian', have_address => \0});

    This method is more forgiving than merge_documents, so you do not have to loop through each individual document to check the status, but you can if you wish.

    Create an index with a variety (but not a complete slice) of the available options:

    my ($error, $result) = $azs->create_index(
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

# AUTHOR

Brian Mielke <bbmielke@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Brian Mielke.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
