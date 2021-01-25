#!/usr/bin/env raku

use v6;

use Test;

use Tinky::DB;
use Red::Database; # for database
use Red::Operators;

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

lives-ok {
    ok $workflow.find-transition($state-new, $state-open) ~~ $open, "find-transition";
}, "find-transition";

my $es;

lives-ok {
    $es = $workflow.enter-supply;
}, "get enter supply";


class Foo does Tinky::DB::Object {
}


$workflow = Tinky::DB::Workflow.^all.grep(*.name eq 'test_workflow').head;


my $obj = Foo.new;


lives-ok { $obj.apply-workflow($workflow) }, "apply workflow";

ok $obj.state ~~ $state-new, "has the right state";

is $obj.transitions.elems, 1, "have one transition";
ok $obj.transitions.head ~~ $open, "have the right transition";

is $obj.next-states.elems, 1, "next-states also has one state";
ok $obj.next-states.head ~~ $state-open, "and it's the right state";

lives-ok {
    ok $obj.transition-for-state($state-open) ~~ $open, "transition-for-state returns the right thing";
}, "transition-for-state";




done-testing;
# vim: expandtab shiftwidth=4 ft=raku
