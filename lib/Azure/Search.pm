package Azure::Search;

use strict;
use warnings;
use Mojo::UserAgent;
use Carp;

our $VERSION = '0.01';

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
      $self->{'service_url'} = "https://$args{service_name}.search.windows.net";
   }
   else {
      carp "Either service_name or service_url are required with Azure::Search";
   }

   my @required_args = qw(index api_version api_key);
   for my $arg (@required_args) {
      $self->{$arg} = $args{$arg} // carp "$arg is required with Azure::Search";
   }

   if ($args{user_agent}) {
      $self->{user_agent} = $args{user_agent};
   }
   else {
      $self->{user_agent} = Mojo::UserAgent->new();
   }
}

sub search_index {
   my ($self, %args) = @_;
   my $url = "$self->{service_url}/indexes/$self->{index}/docs/search?api-version=$self->{api_version}";
   return $self->{user_agent}->post($url => {'api-key' => $self->{api_key}} => json => \%args);
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

=item search_index(%args)

This will run a query on your $azs object to query your search index with %args passed
along to the rest api.  I will provide some examples below, but for a full list of
options please go to the Microsoft site at L<http://docs.microsoft.com/en-us/rest/api/searchservice/search-documents>

=back

=head1 EXAMPLES

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

=head1 AUTHOR

Brian Mielke <bbmielke@gmail.com>

=cut