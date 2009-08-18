use inc::Module::Install;

name     'PPIx-XPath';
license  'perl';
all_from 'lib/PPIx/XPath.pm';

requires 'Tree::XPathEngine' => 0,
         'PPI'               => '1.2',
         'Scalar::Util'      => 0,
         'Carp'              => 0,
         'perl'              => '5.6.0',
;

test_requires 'Test::Most'   => 0,
;

WriteAll;
