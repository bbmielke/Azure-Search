# NAME

Azure::Search

# VERSION

version 0.01

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
    along to the rest api.  I will provide some examples below, but for a full list of
    options please go to:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/search-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/search-documents)

- upload\_documents(@documents)

    Upload an array of hash ref documents to the index.  This replaces the document
    if it already exists in the index.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- merge\_documents(@documents)

    Merge documents onto the index.  This fails if the document does not already exist
    in the index, and it merges the hash keys.

    Merge documents can return a success on $tx->success, while still having errors on individual documents.
    You should loop through each document to see each documents status.  See the EXAMPLE below (or review search\_online.t for example)

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- merge\_or\_upload\_documents(@documents)

    Merge or upload documents onto the index.  It does not overwrite and it does create if needed.
    This method is more forgiving than merge in the situation where a document does not exist in
    the index yet, so you do not have to loop through the status of each individual document
    being merge\_or\_uploaded.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

- delete\_documents(@documents)

    Delete documents from the index -- not individual fields. The microsoft documentation states
    to delete a field use merge instead, and submit the document with a null (undef in perl)
    value for the field you wish to delete.

    For more information on upload, merge\_or\_upload, or delete look at:

    [https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents](https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents)

# NAME

Azure::Search - Perl interacting with Azure Search's REST API.

# EXAMPLES

    Search for anything and grab the first value and a count of matches.

    my $tx = $azs->search_documents(
        search      => '*',
        count       => \1,
        top         => 1,
    );

    Review $tx for search_documents errors:

    if (!$tx->success) {
        my $code = $tx->error->{code};
        my $message = $tx->error->{message};
        my $body = $tx->result->body;
        carp "Azure Search Call returned: $code: $message: $body";
    }
    else {
        say "NUMBER OF RESULTS: " . $tx->result->json->{'@odata.count'};
        say "DUMP OF RESULTS: " . Dumper($tx->result->json);
    }

    Search the index by the name field, where the name is not Brian.
    Filter the results further for non-Brians who have an address
    and a date lt 2018-06-26. Please note boolean and date fields
    can not be searched directly, but they can be filtered.

    my $tx = $azs->search_documents(
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
        carp "Azure Search Call returned: $code: $message: $body";
    }

    #Modify existing documents with new hash entries:

    my $tx = $azs->merge_documents({'name' => 'does not exist yet', have_address=>\0}, {'name' => 'Brian', have_address => \0});

    # Review $tx for merge_documents errors:

    if (!$tx->success) {
        my $code = $tx->error->{code};
        my $message = $tx->error->{message};
        my $body = $tx->result->body;
        carp "Azure Search Call returned: $code: $message: $body";
    }
    else {
        for my $document (@{$tx->result->json->{value}}) {
            if($document->{'statusCode'} != 200) {
                carp "Document uploaded with unexpected statusCode - $document->{'key'}: $document->{statusCode}: $document->{errorMessage}";
            }
        }
    }

    Upload documents without overwriting all old hash entries with merge_or_upload:

    my $tx = $azs->merge_or_upload_documents({'name' => 'does not exist yet', have_address=>\0}, {'name' => 'Brian', have_address => \0});

    This method is more forgiving than merge_documents, so you do not have to loop through each individual document to check the status, but you can if you wish.

# AUTHOR

Brian Mielke <bbmielke@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Brian Mielke.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
