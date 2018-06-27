use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME               => 'Azure::Search',
   DISTNAME           => 'Azure-Search',
   AUTHOR             => 'Brian Mielke <bbmielke@gmail.com>',
   VERSION_FROM       => 'lib/Azure/Search.pm',
   ABSTRACT           => 'Interacting with Azure Search Service',
   LICENSE            => 'artistic_2',
   CONFIGURE_REQUIRES => {'ExtUtils::MakeMaker' => 0,},
   PREREQ_PM          => {'Mojo::UserAgent' => 0, 'Carp' => 0,},
   TEST_REQUIRES      => {'ExtUtils::MakeMaker' => 0, 'Test::More' => 0, 'Mojolicious::Lite' => 0,},
   META_MERGE         => {
      dynamic_config => 0,
      'meta-spec'    => {version => 2},
      resources      => {
         bugtracker => {web => 'https://github.com/bbmielke/Azure-Search/issues'},
         homepage   => 'https://github.com/bbmielke/Azure-Search',
         license    => ['http://www.opensource.org/licenses/artistic-license-2.0'],
         repository => {type => 'git', url => 'https://github.com/bbmielke/Azure-Search.git', web => 'https://github.com/bbmielke/Azure-Search',},
      },
   },
);
