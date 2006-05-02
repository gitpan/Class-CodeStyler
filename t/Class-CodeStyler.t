# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Class-CodeStyler.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

#use Test::More tests => 1;
#BEGIN { use_ok('Class::CodeStyler') };

use Test;
use Class::CodeStyler;
BEGIN { plan tests => 5 }

#########################

my $p2 = Class::CodeStyler::Program::Perl->new();
$p2->code("sub function_operator");
$p2->open_block();
	$p2->code("my \$self = shift;");
	$p2->code("my \$arg1 = shift;");
	$p2->code("my \$arg2 = shift;");
	$p2->code("return \$arg1->eq(\$arg2);");
$p2->close_block();
$p2->prepare();

ok ($p2->print(), "sub function_operator\n{\n  my \$self = shift;\n  my \$arg1 = shift;\n  my \$arg2 = shift;\n  return \$arg1->eq(\$arg2);\n}\n", 
	'open/close_block()');

my $p = Class::CodeStyler::Program::Perl->new(program_name => 'testing.pl', tab_size => 4);
ok ($p->program_name(), 'testing.pl', 'program_name()');

$p->open_block();
	$p->code("package MyBinFun;");
	$p->bookmark('subs');
	$p->indent_off();
	$p->comment("Subroutines above...");
	$p->indent_on();
$p->close_block();
$p->prepare();
ok ($p->print(), "{\n    package MyBinFun;\n    # BOOKMARK ---- subs\n#Subroutines above...\n}\n", 
	'tab_size, indent_on/off, comment()');

$p->jump('subs');
$p->add($p2);
$p->clear();
$p->prepare();
ok ($p->print(), 
"{\n    package MyBinFun;"
. "\n    sub function_operator\n    {\n      my \$self = shift;\n      my \$arg1 = shift;"
. "\n      my \$arg2 = shift;\n      return \$arg1->eq(\$arg2);\n    }"
. "\n    # BOOKMARK ---- subs\n#Subroutines above...\n}\n",
	'jump(), clear(), add()');

$p->return();
$p->divider();
$p->comment('Next package follows...');
$p->open_block();
	$p->code("package MyUFun;");
$p->close_block();
$p->clear();
$p->prepare();

ok ($p->print(), "{\n    package MyBinFun;\n    sub function_operator"
. "\n    {\n      my \$self = shift;\n      my \$arg1 = shift;\n      my \$arg2 = shift;"
. "\n      return \$arg1->eq(\$arg2);\n    }\n    # BOOKMARK ---- subs"
. "\n#Subroutines above...\n}"
. "\n#----------------------------------------------------------------------"
. "\n#Next package follows...\n{"
. "\n    package MyUFun;\n}\n",
	'return(), divider()');
