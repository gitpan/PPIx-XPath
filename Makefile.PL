# require 5.005;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'PPIx::XPath',
  VERSION_FROM => 'lib/PPIx/XPath.pm',
  AUTHOR       => 'Dan Brook',

  PREREQ_PM    => {
    'Class::XPath' => 0,
    'PPI'          => 0,
  },
);
