#!raku

use v6;

use Test;
plan 53;

use Tinky;
use Tinky::DB;
use Red;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);
my $*RED-COMMENT-SQL = True;

Tinky::DB::Workflow.^create-table;
Tinky::DB::State.^create-table;
Tinky::DB::Transition.^create-table;
Tinky::DB::Item.^create-table;


my $workflow = Tinky::DB::Workflow.^create( name => "test_worflow");


if %*ENV<TRAVIS> {
    todo "Flappy on travis-ci for some unknown reason", 53;
}

model ObjectOne does Tinky::DB::Object {
    has Int $.id is serial;
}

ObjectOne.^create-table;

model ObjectTwo does Tinky::DB::Object {
    has Int $.id is serial;
}
ObjectTwo.^create-table;

model ObjectThree does Tinky::DB::Object {
    has Int $.id is serial;
}
ObjectThree.^create-table;

my Tinky::DB::State $state_one = $workflow.states.create(name => 'one');

$state_one.enter-validators.push: sub (ObjectOne $) returns Bool { True };
$state_one.enter-validators.push: sub (ObjectTwo $) returns Bool { False };

ok do {  await  $state_one.validate-enter(ObjectOne.^create) }, "validate-enter with a specific True validator";
nok do {  await $state_one.validate-enter(ObjectTwo.^create) }, "validate-enter with a specific False validator";
ok do {  await  $state_one.validate-enter(ObjectThree.^create) }, "validate-enter with no specific validator";

$state_one.leave-validators.push: sub (ObjectOne $) returns Bool { True };
$state_one.leave-validators.push: sub (ObjectTwo $) returns Bool { False };

ok do {  await  $state_one.validate-leave(ObjectOne.^create) }, "validate-leave with a specific True validator";
nok do {  await $state_one.validate-leave(ObjectTwo.^create) }, "validate-leave with a specific False validator";
ok do {  await  $state_one.validate-leave(ObjectThree.^create) }, "validate-leave with no specific validator";

my $foo = $workflow.states.create(name => "foo");
my $bar = $workflow.states.create(name => "bar");

my $trans = $workflow.transitions.create(name => 'test-transition', from => $foo, to => $bar);

$trans.validators.push: sub (ObjectOne $) returns Bool { True };
$trans.validators.push: sub (ObjectTwo $) returns Bool { False };

ok do {  await  $trans.validate(ObjectOne.^create) }, "Transition.validate with a specific True validator";
nok do {  await $trans.validate(ObjectTwo.^create) }, "Transition.validate with a specific False validator";
ok do {  await  $trans.validate(ObjectThree.^create) }, "Transition.validate with no specific validator";

$trans.validators.push: sub (Tinky::Object $) returns Bool { False };

nok do {  await  $trans.validate(ObjectOne.^create) }, "Transition.validate with a specific True validator but a non-specific False validator";
nok do {  await $trans.validate(ObjectTwo.^create) }, "Transition.validate with a specific False validator but a non-specific False validator";
nok do {  await  $trans.validate(ObjectThree.^create) }, "Transition.validate with no specific validator but a non-specific False validator";

my $foo2 = $workflow.states.create(name => "foo-2");
my $bar2 = $workflow.states.create(name => "bar-2");

$trans = $workflow.transitions.create(name => 'test-transition-2', from => $foo2, to => $bar2);

ok do {  await  $trans.validate-apply(ObjectOne.^create) }, "Transition.validate-apply with no specific validators";
ok do {  await $trans.validate-apply(ObjectTwo.^create) }, "Transition.validate-apply with no specific validators";
ok do {  await  $trans.validate-apply(ObjectThree.^create) }, "Transition.validate-apply with no specific validators";

$trans.validators.push: sub (ObjectOne $) returns Bool { False };

nok do {  await  $trans.validate-apply(ObjectOne.^create) }, "Transition.validate-apply with specific False validators on Transiion";
ok do {  await  $trans.validate-apply(ObjectTwo.^create) }, "Transition.validate-apply with specific False validators on Transition on another object";
ok do {  await  $trans.validate-apply(ObjectThree.^create) }, "Transition.validate-apply with specific False validators on Transiion on another object";

$trans.from.leave-validators.push: sub (ObjectTwo $) returns Bool { False };
nok do {  await  $trans.validate-apply(ObjectOne.^create) }, "Transition.validate-apply with specific False validators on Transiion";
nok do {  await  $trans.validate-apply(ObjectTwo.^create) }, "Transition.validate-apply with specific False validators on leave from";
ok do {  await  $trans.validate-apply(ObjectThree.^create) }, "Transition.validate-apply with specific False validators on Transition on another object";

$trans.to.enter-validators.push: sub (ObjectThree $) returns Bool { False };
nok do {  await  $trans.validate-apply(ObjectOne.^create) }, "Transition.validate-apply with specific False validators on Transiion";
nok do {  await  $trans.validate-apply(ObjectTwo.^create) }, "Transition.validate-apply with specific False validators on leave from";
nok do {  await  $trans.validate-apply(ObjectThree.^create) }, "Transition.validate-apply with specific False validators on enter to";

my $wf = Tinky::DB::Workflow.^create(name => "workflow-2");

my @states = <one two three four>.map({ $wf.states.create(name => $_) });
my @transitions = @states.rotor(2 => -1).map(-> ($from, $to) { my $name = $from.name ~ '-' ~ $to.name; $wf.transitions.create(:$from, :$to, :$name) });
$wf.initial-state = @states[0];
$wf.^save;


@transitions[0].validators.push: sub (ObjectOne $) returns Bool { False };

my $one = ObjectOne.^create;
$one.apply-workflow($wf);

throws-like { $one.apply-transition(@transitions[0]) }, Tinky::X::TransitionRejected, "transition rejected";

my $two = ObjectTwo.^create;
$two.apply-workflow($wf);

lives-ok { $two.apply-transition(@transitions[0]) }, "another object is okay";

@transitions[1].to.enter-validators.push: sub (ObjectTwo $) returns Bool { False };

throws-like { $two.apply-transition(@transitions[1]) }, Tinky::X::TransitionRejected, "transition rejected (with fail on to state)";

# Tests for methods
# multi sub trait_mod:<is> ( Method $m, :$enter-validator! ) is export
# multi sub trait_mod:<is> (Method $m, :$leave-validator! ) is export
# multi sub trait_mod:<is> (Method $m, :$transition-validator! ) is export


my $wf2 = Tinky::DB::Workflow.^create(name => 'workflow-3');


model WontLeave does Tinky::DB::Object {
    has Int $.id is serial;
}
WontLeave.^create-table;
model WontEnter does Tinky::DB::Object {
    has Int $.id is serial;
}
WontEnter.^create-table;
model WontApply does Tinky::DB::Object {
    has Int $.id is serial;
}
WontApply.^create-table;

class FooState does Tinky::DB::Helper {
    method no-leave(WontLeave $obj) returns Bool is leave-validator {
        False;
    }
    method no-enter(WontEnter $obj) returns Bool is enter-validator {
        False;
    }
}

class FooTransition does Tinky::DB::Helper {
    method no-apply(WontApply $obj) returns Bool is transition-validator {
        False;
    }
}

my $foo-state-one = $wf2.states.create(name => 'one', helper-class => 'FooState');
my $foo-state-two = $wf2.states.create(name => 'two', helper-class => 'FooState');
my $foo-transition = $wf2.transitions.create(name => 'foo', from-id => $foo-state-one.id, to-id => $foo-state-two.id, helper-class => 'FooTransition');

$wf2.initial-state = $foo-state-one;
$wf2.^save;


ok do { await $foo-transition.to.validate-enter(WontLeave.^create) }, "validate-enter with state enter-validator that doesn't match";
nok do { await $foo-transition.to.validate-enter(WontEnter.^create) }, "validate-enter with state enter-validator that does match";
ok do { await $foo-transition.to.validate-enter(WontApply.^create) }, "validate-enter with state enter-validator that doesn't match (transition only)";

nok do { await $foo-transition.to.validate-leave(WontLeave.^create) }, "validate-leave with state leave-validator that does match";
ok do { await $foo-transition.to.validate-leave(WontEnter.^create) }, "validate-leave with state leave-validator that doesn't match";
ok do { await $foo-transition.to.validate-leave(WontApply.^create) }, "validate-leave with state leave-validator that doesn't match (transition only)";

ok do { await $foo-transition.validate(WontLeave.^create) }, "Transition.validate with validator, no match (has a leve-validate)";
ok do { await $foo-transition.validate(WontEnter.^create) }, "Transition.validate with validator, no match (has an enter-validate)";
nok do { await $foo-transition.validate(WontApply.^create) }, "Transition.validate with validator, with matching transition-validator";

nok do { await $foo-transition.validate-apply(WontLeave.^create) }, "Transition.validate-apply with leave-validator";
nok do { await $foo-transition.validate-apply(WontEnter.^create) }, "Transition.validate-apply with validator, with enter-validate)";
nok do { await $foo-transition.validate-apply(WontApply.^create) }, "Transition.validate-apply with validator, with matching transition-validator";

# my $new-wf = Tinky::DB::Workflow.^create(transitions => [$foo-transition], name => "foo-workflow");
my $new-wf = $wf2;

model SafeOne does Tinky::DB::Object {
    has Int $.id is serial;
}
SafeOne.^create-table;

my $wont-leave = WontLeave.^create(state => $foo-transition.from);
$wont-leave.apply-workflow($new-wf);
throws-like { $wont-leave.apply-transition($foo-transition) }, Tinky::X::TransitionRejected, "apply-transition fails with leave-validator";
my $wont-enter = WontEnter.^create(state => $foo-transition.from);
$wont-enter.apply-workflow($new-wf);
throws-like { diag $wont-enter.apply-transition($foo-transition) }, Tinky::X::TransitionRejected, "apply-transition fails with enter-validator";
my $wont-apply = WontApply.^create(state => $foo-transition.from);
$wont-apply.apply-workflow($new-wf);
throws-like { diag $wont-apply.apply-transition($foo-transition) }, Tinky::X::TransitionRejected, "apply-transition fails with apply-validator";
my $safe = SafeOne.^create(state => $foo-transition.from);
$safe.apply-workflow($new-wf);
lives-ok { $safe.apply-transition($foo-transition) }, "object with no specific validators applies fine";
ok $safe.state ~~ $foo-transition.to, "and the state got changed fine";

# Test for workflow application validation

model WorkflowGood does Tinky::DB::Object {
    has Int $.id is serial;
}
WorkflowGood.^create-table;

model WorkflowBad does Tinky::DB::Object {
    has Int $.id is serial;
}
WorkflowBad.^create-table;

my $apply-workflow = Tinky::DB::Workflow.^create(name => 'workflow-apply-test-workflow');

$apply-workflow.validators.push: sub (WorkflowBad $obj) returns Bool { False };

ok do { await $apply-workflow.validate-apply(WorkflowGood.^create) }, "Workflow.validate-apply with no validator";
nok do { await $apply-workflow.validate-apply(WorkflowBad.^create) }, "Workflow.validate-apply with False validator";
$apply-workflow.validators.push: sub (WorkflowGood $obj) returns Bool { True };
ok do { await $apply-workflow.validate-apply(WorkflowGood.^create) }, "Workflow.validate-apply with True validator";

throws-like { WorkflowBad.^create.apply-workflow($apply-workflow) }, Tinky::X::ObjectRejected, "Workflow.apply-workflow with False validate as sub";
lives-ok { WorkflowGood.^create.apply-workflow($apply-workflow) }, "Workflow.apply-workflow with True validate as sub";

class TestWorkflowHelper is Tinky::DB::Helper {
    method reject-bad(WorkflowBad $obj) returns Bool is apply-validator {
        False;
    }
    method accept-good(WorkflowGood $obj) returns Bool is apply-validator {
        True;
    }
}

my $apply-wf-meths = Tinky::DB::Workflow.^create(name => 'test-workflow-helper', helper-class => 'TestWorkflowHelper');

nok do { await $apply-wf-meths.validate-apply(WorkflowBad.^create) }, "Workflow.validate-apply with False validator as method";
ok do { await $apply-wf-meths.validate-apply(WorkflowGood.^create) }, "Workflow.validate-apply with True validator as method";

throws-like { WorkflowBad.^create.apply-workflow($apply-wf-meths) }, Tinky::X::ObjectRejected, "Workflow.apply-workflow with False validate as method";
lives-ok { WorkflowGood.^create.apply-workflow($apply-wf-meths) }, "Workflow.apply-workflow with True validate as method";


done-testing;
# vim: expandtab shiftwidth=4 ft=raku
