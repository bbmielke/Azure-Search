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

    my $tx = $azs->search_index(
        search      => '*',
        count       => \1,
        top         => 1,
    );

    # Parse rest response as you would with other Mojo::Transaction::HTTP object

    if (!$tx->success) {
        my $code = $tx->error->{code};
        my $message = $tx->error->{message};
        carp "Azure Search Call returned: $code: $message";
    }
    elsif ($tx->result->code != 200) {
        my $code = $tx->result->code;
        my $body = $tx->result->body;
        carp "Azure Search Call returned: $code: $body";
    }
    else {
        say "NUMBER OF RESULTS: " . $tx->result->json->{'@odata.count'};
        say "DUMP OF RESULTS: " . Dumper($tx->result->json);
    }

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

- search\_index(%args)

    This will run a query on your $azs object to query your search index with %args passed
    along to the rest api.  I will provide some examples below, but for a full list of
    options please go to the Microsoft site at [http://docs.microsoft.com/en-us/rest/api/searchservice/search-documents](http://docs.microsoft.com/en-us/rest/api/searchservice/search-documents)

# NAME

Azure::Search - Perl interacting with Azure Search's REST API.

# EXAMPLES

    Search for anything and grab the first value and a count of matches.

    my $tx = $azs->search_index(
        search      => '*',
        count       => \1,
        top         => 1,
    );

    Search the index by the name field, where the name is not Brian.
    Filter the results further for non-Brians who have an address
    and a date lt 2018-06-26. Please note boolean and date fields
    can not be searched directly, but they can be filtered.

    my $tx = $azs->search_index(
        search    => '-name:Brian',
        top       => 100,
        queryType => 'full',
        count     => \1,
        select    => 'name',
        filter    => 'date lt 2018-06-26 AND have_address eq true',
    );

# AUTHOR

Brian Mielke <bbmielke@gmail.com>

# AUTHOR

Brian Mielke <bbmielke@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Brian Mielke.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
