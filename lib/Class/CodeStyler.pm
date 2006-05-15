# vim:ts=4 sw=4
# ----------------------------------------------------------------------------------------------------
#  Name		: Class::CodeStyler.pm
#  Created	: 24 April 2006
#  Author	: Mario Gaffiero (gaffie)
#
# Copyright 2006 Mario Gaffiero.
# 
# This file is part of Class::CodeStyler(TM).
# 
# Class::CodeStyler is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# Class::CodeStyler is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Class::CodeStyler; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# ----------------------------------------------------------------------------------------------------
# Modification History
# When          Version     Who     What
# ----------------------------------------------------------------------------------------------------
package Class::CodeStyler;
require 5.005_62;
use strict;
use warnings;
use vars qw($VERSION $BUILD);
$VERSION = 0.07;
$BUILD = 'Friday April 28 21:56:42 GMT 2006';
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Element::Abstract;
	use base qw(Class::STL::Element);
	use Class::STL::ClassMembers qw(owner);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		use Carp qw(confess);
		confess __PACKAGE__ . "::prepare() -- pure virtual function must be overridden.";
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Program;
	use base qw(Class::CodeStyler::Element::Abstract);
	use stl 0.26;
	use UNIVERSAL qw(isa can);
	use Class::STL::ClassMembers 
	(
		qw(
			program_name sections code_text _bracket_stack 
			_parent _insert_point _jump_stack _over_stack
		),
		Class::STL::ClassMembers::DataMember->new(name => 'suppress_comments', default => 0),
		Class::STL::ClassMembers::DataMember->new(name => 'tab_size', default => 2),
		Class::STL::ClassMembers::DataMember->new(name => 'tab_type', default => 'spaces', validate => '(hard|spaces)'),
		Class::STL::ClassMembers::DataMember->new(name => 'debug', default => 0),
		Class::STL::ClassMembers::DataMember->new(name => '_current_tab', default => 0),
		Class::STL::ClassMembers::DataMember->new(name => '_newline_is_on',	default => 1),
		Class::STL::ClassMembers::DataMember->new(name => '_indent_is_on', default => 1),
		Class::STL::ClassMembers::DataMember->new(name => '_indent_next', default => 1),
		Class::STL::ClassMembers::DataMember->new(name => 'divider_length', default => 70),
		Class::STL::ClassMembers::DataMember->new(name => 'divider_char', default => '-'),
		Class::STL::ClassMembers::DataMember->new(name => 'comment_start_char', default => ''),
		Class::STL::ClassMembers::DataMember->new(name => 'comment_block_begin_char', default => ''),
		Class::STL::ClassMembers::DataMember->new(name => 'comment_block_end_char', default => ''),
		Class::STL::ClassMembers::DataMember->new(name => 'comment_block_char', default => ''),
	);
	use Class::STL::ClassMembers::Constructor;
	sub new_extra
	{
		my $self = shift;
		$self->code_text(stack()) unless (defined($self->code_text()));
		$self->sections(list(element_type => 'Class::CodeStyler::Element::Abstract'));
		$self->_bracket_stack(stack());
		$self->_jump_stack(stack());
		$self->_insert_point(iterator($self->sections()->begin()));
#		$self->_bracket_map(::map());
		return $self;
	}
	sub add
	{
		my $self = shift;
		foreach my $code (grep(ref($_), @_))
		{
			if (ref($code) && $code->isa(__PACKAGE__))
			{
				$code->code_text($self->code_text());
				$code->_parent($self);
			}
			$self->sections()->insert($self->_insert_point(), $code);
		}
	}
	sub code
	{
		my $self = shift;
		my $code = shift;
		$self->add(Class::CodeStyler::Code->new(code => $code, owner => $self));
	}
	sub open_block
	{
		my $self = shift;
		my $bracket = shift || '{';
		my %_bracket_pairs = ( '(' => ')', '{' => '}', '[' => ']', '<' => '>' );
		$self->add(Class::CodeStyler::OpenBlock->new(bracket_char => $bracket, owner => $self));
		$self->_bracket_stack()->push($self->_bracket_stack()->factory($_bracket_pairs{$bracket}));
		return;
	}
	sub close_block
	{
		my $self = shift;
		my $bracket = $self->_bracket_stack()->top()->data();
		$self->_bracket_stack()->pop();
		$self->add(Class::CodeStyler::CloseBlock->new(bracket_char => $bracket, owner => $self));
		return;
	}
	sub newline_on
	{
		my $self = shift;
		$self->add(Class::CodeStyler::ToggleNewline->new(on => 1, owner => $self));
	}
	sub newline_off
	{
		my $self = shift;
		$self->add(Class::CodeStyler::ToggleNewline->new(on => 0, owner => $self));
	}
	sub indent_on
	{
		my $self = shift;
		$self->add(Class::CodeStyler::ToggleIndent->new(on => 1, owner => $self));
	}
	sub indent_off
	{
		my $self = shift;
		$self->add(Class::CodeStyler::ToggleIndent->new(on => 0, owner => $self));
	}
	sub over
	{
		my $self = shift;
		my $indent = shift || 1;
		$self->add(Class::CodeStyler::Indent->new(indent => $indent, owner => $self));
		$self->_over_stack()->push($self->_over_stack()->factory($indent));
		return;
	}
	sub back
	{
		my $self = shift;
		$self->add(Class::CodeStyler::Indent->new(indent => -($self->_over_stack()->top()->data()), owner => $self));
		$self->_over_stack()->pop();
		return;
	}
	sub comment
	{
		my $self = shift;
		my $txt = shift;
		$self->add(Class::CodeStyler::Comment->new(data => $txt, owner => $self));
	}
	sub divider
	{
		my $self = shift;
		$self->add(Class::CodeStyler::Divider->new(owner => $self));
	}
	sub bookmark
	{
		my $self = shift;
		my $id = shift;
		$self->add(Class::CodeStyler::Bookmark->new(data => $id, owner => $self));
	}
	sub jump
	{
		my $self = shift;
		my $id = shift;
		my $found;
		if ($found = find($self->sections()->begin(), $self->sections()->end(), $id))
		{
			$self->_jump_stack()->push($self->_insert_point()->clone());
			$self->_insert_point($found);
			return;
		}
		use Carp qw(confess);
		confess "Unknown bookmark '$id'!\n";
	}
	sub return
	{
		my $self = shift;
		$self->_insert_point($self->_jump_stack()->top()->clone());
		$self->_jump_stack()->pop();
	}
	sub clear
	{
		my $self = shift;
		$self->code_text()->clear();
	}
	sub prepare
	{
		my $self = shift;
		# This works because all 'sections' elements are (ultimately) derived 
		# from Class::CodeStyler::Element::Abstract. Recursion via this prepare() will
		# occure if the element is a Class::CodeStyler::Program.
		for_each($self->sections()->begin(), $self->sections()->end(), mem_fun('prepare'));
	}
	sub print
	{
		my $self = shift;
		return $self->code_text()->join('');
	}
	sub save
	{
		my $self = shift;
		my $filename = shift || $self->program_name();
		use Carp qw(confess);
		confess "save() -- Unable to save -- 'program_name' is not defined."
			unless defined($filename);
		open(SAVE, ">@{[ $filename ]}");
		print SAVE $self->print();
	}
	sub display
	{
		my $self = shift;
		my $line_number = 1;
		foreach (split(/\n/, $self->print()))
		{
			print sprintf("%5d %s\n", $line_number++, $_);
		}
	}
	sub syntax_check
	{
		my $self = shift;
		$self->save("@{[ $self->program_name() ]}.DEBUG");
		my $check = `perl -cw @{[ $self->program_name() ]}.DEBUG 2>&1`;
		chomp($check);
		if ($check !~ /syntax OK/i)
		{
			$self->code("__END__");
			$self->code("Syntax check summary follows:");
			$self->code("$check");
			$self->clear();
			$self->prepare();
			$self->save("@{[ $self->program_name() ]}.DEBUG");
		}
		else
		{
			unlink "@{[ $self->program_name() ]}.DEBUG";
		}
		return $check;
	}
	sub exec
	{
		my $self = shift;
		$self->save("@{[ $self->program_name() ]}.EXEC");
		exec("perl @{[ $self->program_name() ]}.EXEC");
	}
	sub eval
	{
		my $self = shift;
		eval($self->print());
		use Carp qw(confess);
		confess "**Error in eval:\n$@" if ($@);
	}
	# ----------------------------------------------------------------------------------------------------
	#	PRIVATE FUNCTIONS
	# ----------------------------------------------------------------------------------------------------
	sub _append_newline
	{
		my $self = shift;
		$self->code_text()->push($self->code_text()->factory("\n"));
		$self->_indent_next(1);
		print STDERR "NEWLINE:\n" if ($self->debug());
	}
	sub _append_text
	{
		my $self = shift;
		my $code = shift;
		$self->code_text()->push($self->code_text()->factory($self->_current_indent() . $code));
		print STDERR "CODE   :@{[ $self->_current_indent() ]}${code}\n" if ($self->debug());
		$self->_indent_next(0);
	}
	sub _current_indent
	{
		my $self = shift;
		return '' if (!$self->_indent_is_on());
		return '' unless (
			$self->_indent_next() 
			|| (defined($self->_parent()) && $self->_parent()->_indent_next())
		);
		my $tabchar = $self->tab_type() eq 'hard' ? "\t" : ' ';
		return ($tabchar x ($self->_current_tab() * $self->tab_size()))
			. (defined($self->_parent()) ? $self->_parent()->_current_indent() : '');
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Program::Perl; 
	use base qw(Class::CodeStyler::Program);
	use Class::STL::ClassMembers::Constructor;
	sub new_extra
	{
		my $self = shift;
		$self->SUPER::new_extra(@_);
		$self->comment_start_char('#');
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Program::C; 
	use base qw(Class::CodeStyler::Program);
	use Class::STL::ClassMembers::Constructor;
	sub new_extra
	{
		my $self = shift;
		$self->SUPER::new_extra(@_);
		$self->comment_start_char('//');
		$self->comment_block_begin_char('/*');
		$self->comment_block_char      (' *');
		$self->comment_block_end_char  (' */');
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Bookmark;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_append_text("# BOOKMARK ---- @{[ $self->data() ]}");
		$self->owner()->_append_newline();
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::OpenBlock;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers qw(bracket_char);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_append_text($self->bracket_char());
		return unless ($self->owner()->_newline_is_on());
		$self->owner()->_current_tab($self->owner()->_current_tab()+1);
		$self->owner()->_append_newline();
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::CloseBlock;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers qw(bracket_char);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_current_tab($self->owner()->_current_tab()-1) if ($self->owner()->_newline_is_on());
		$self->owner()->_append_text($self->bracket_char());
		$self->owner()->_append_newline() if ($self->owner()->_newline_is_on());
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Code;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers qw(code);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_append_text($self->code());
		$self->owner()->_append_newline() if ($self->owner()->_newline_is_on());
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Comment;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_append_text($self->owner()->comment_start_char() . $self->data());
		$self->owner()->_append_newline() if ($self->owner()->_newline_is_on());
	}
}
# ----------------------------------------------------------------------------------------------------
{#TODO:
	package Class::CodeStyler::CommentBegin;
}
# ----------------------------------------------------------------------------------------------------
{#TODO:
	package Class::CodeStyler::CommentEnd;
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Divider;
	use base qw(Class::CodeStyler::Element::Abstract);
	sub prepare
	{
		my $self = shift;
		$self->owner()->_append_text($self->owner()->comment_start_char());
		$self->owner()->_append_text($self->owner()->divider_char() x $self->owner()->divider_length());
		$self->owner()->_append_newline() if ($self->owner()->_newline_is_on());
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::ToggleNewline;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers qw(on);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_newline_is_on($self->on());
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::ToggleIndent;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers qw(on);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_indent_is_on($self->on());
	}
}
# ----------------------------------------------------------------------------------------------------
{
	package Class::CodeStyler::Indent;
	use base qw(Class::CodeStyler::Element::Abstract);
	use Class::STL::ClassMembers qw(indent);
	use Class::STL::ClassMembers::Constructor;
	sub prepare
	{
		my $self = shift;
		$self->owner()->_current_tab($self->owner()->_current_tab()+$self->indent());
	}
}
# ----------------------------------------------------------------------------------------------------
#TODO: User can extend Class::CodeStyler::Element::Abstract to provide specific code-blocks...
1;
