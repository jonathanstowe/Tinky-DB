#!/usr/bin/env raku

use v6;

use Test;

use Tinky;
use Tinky::DB;
use Red::Database; # for database
use Red::Operators;
use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

lives-ok { Tinky::DB::Workflow.^create-table }, "create workflow table";
lives-ok { Tinky::DB::State.^create-table    }, "create state table";;
lives-ok { Tinky::DB::Transition.^create-table }, "create transition table";
lives-ok { Tinky::DB::Item.^create-table }, "create item table";

my $wf = Tinky::DB::Workflow.^create(name => "test workflow");

my @states = <one two three four>.map({ $wf.states.create(name => $_) });

$wf.initial-state = @states[0];
$wf.^save;

my @transitions = @states.rotor(2 => -1).map(-> ($from, $to) { my $name = $from.name ~ '-' ~ $to.name; $wf.transitions.create(:$from, :$to, :$name) });

model FooTest does Tinky::DB::Object {
    has Int $.id is serial;
}

FooTest.^create-table;

my $obj = FooTest.^create;

$obj.apply-workflow($wf);

for @transitions -> $trans {
    for @transitions.grep({ $obj !~~ $_ }) -> $no-trans {
        throws-like { $obj.apply-transition($no-trans) }, Tinky::X::InvalidTransition, "throws trying to apply wrong transition";
    }

    lives-ok { $obj.apply-transition($trans) }, "apply-transition with '{ $trans.name }' lives";
    is $obj.state, $trans.to, "and it is in the expected state";
}

$obj = FooTest.new;
throws-like {  $obj.apply-transition(@transitions[0]) }, Tinky::X::NoState, "should throw X::NoState with apply-transition and state not set";

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
