#!/usr/bin/env perl6

use v6;

use Test;

use Tinky::DB;
use Red; # for database

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

lives-ok { Tinky::DB::Workflow.^create-table }, "create workflow table";
lives-ok { Tinky::DB::State.^create-table    }, "create state table";;
lives-ok { Tinky::DB::Transition.^create-table }, "create transition table";

my $workflow;
lives-ok { $workflow = Tinky::DB::Workflow.^create: name => "test_workflow" }, "create workflow";

my $state-new;
lives-ok { $state-new = $workflow.states.create(name => 'new') }, "create 'new' state";
lives-ok { $workflow.initial-state = $state-new; $workflow.^save }, "set initial state on workflow";
my $state-open;
lives-ok { $state-open = $workflow.states.create(name => 'open') }, "create 'open' state";
my $state-complete;
lives-ok { $state-complete = $workflow.states.create(name => 'complete') }, "create 'complete' state";

is $workflow.states.elems, 3, "now got three states";

my $open;
lives-ok { $open = $workflow.transitions.create(name => "open", from-id => $state-new.id, to-id => $state-open.id ) }, "create 'open' transition";

my $complete;
lives-ok { $complete = $workflow.transitions.create(name => "complete", from-id => $state-open.id, to-id => $state-complete.id ) }, "create 'complete' transition";

is $workflow.transitions.elems, 2, "got two transitions";

is $workflow.transitions-for-state($state-new).elems, 1, "transitions-for-state";
is $workflow.transitions-for-state($state-new).head.id, $open.id, "and it's the one we expected";





done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
