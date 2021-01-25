use v6;

use Tinky :ALL;
use Red;

module Tinky::DB {

    sub load-if-required(Str $f) {
        my $t = ::($f);
        if !$t && $t ~~ Failure {
            $t = (require ::($f))
        }
        $t
    }

    model State { ... }

    role Object does Tinky::Object is export {
    }

    role Helper {
    }

    role WithHelper {
        has Helper  $.helper;
        method helper(--> Helper) {
            $!helper //= do {
                if $.helper-class.defined {
                    my $h = load-if-required($.helper-class);
                    $h.new;
                }
                else {
                    Helper
                }
            }
        }
    }

    model Workflow is Tinky::Workflow does WithHelper is table('tinky_workflow') is rw {
        has Int     $.id                is serial;
        has Str     $.name              is column(:unique);
        has Int     $.initial-state-id  is referencing(column => 'id', model => 'Tinky::DB::State', require => 'Tinky::DB');
        has         $.initial-state     is relationship({ .initial-state-id }, model => 'Tinky::DB::State', require => 'Tinky::DB');
        has         @.states            is relationship({ .workflow-id }, model => 'Tinky::DB::State', require => 'Tinky::DB' );
        has         @.transitions       is relationship({ .workflow-id }, model => 'Tinky::DB::Transition', require => 'Tinky::DB' );
        has Str     $.helper-class      is column(:nullable);

        method transitions-for-state(State:D $state ) {
            self.transitions.grep(*.from-id == $state.id);
        }

        multi method find-transition(State:D $from, State:D $to) {
            self.transitions-for-state($from).first( { $_.to-id == $to.id });
        }

        method validate-apply(Object:D $object --> Promise ) {
            validate-helper($object, ( @.validators, $.helper.defined ?? validate-methods($.helper, $object, ApplyValidator) !! Empty ).flat);
        }

    }

    model State is Tinky::State does WithHelper is table('tinky_state') is rw {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Tinky::DB::Workflow', column => 'id', require => 'Tinky::DB');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Tinky::DB::Workflow', require => 'Tinky::DB');
        has Str     $.helper-class      is column(:nullable);

        multi method ACCEPTS(State:D $state --> Bool ) {
            self.id == $state.id
        }

        my Supplier $enter-supplier;

        method !enter-supplier(--> Supplier ) {
            $enter-supplier //= Supplier.new;
        }

        method enter-supply( --> Supply ) {
            self!enter-supplier.Supply.grep( -> $ ( $s, $o ) { $s.id == self.id } ).map( -> $ ($, $o) { $o } );
        }

        method enter(Object:D $object) {
            self!enter-supplier.emit([self, $object]);
        }

        my Supplier $leave-supplier;

        method !leave-supplier( --> Supplier ) {
            $leave-supplier //= Supplier.new;
        }

        method leave-supply( --> Supply ) {
            self!leave-supplier.Supply.grep( -> $ ( $s, $o ) { $s.id == self.id } ).map( -> $ ($, $o) { $o } );
        }

        method leave(Object:D $object) {
            self!leave-supplier.emit([self, $object]);
        }

        method validate-phase(Str $phase where 'enter'|'leave', Object $object --> Promise ) {
            my @subs = do given $phase {
                when 'leave' {
                    (@.leave-validators, $.helper.defined ?? validate-methods($.helper, $object, LeaveValidator) !! Empty ).flat;
                }
                when 'enter' {
                    (@.enter-validators, $.helper.defined ?? validate-methods($.helper, $object, EnterValidator) !! Empty ).flat;
                }
            }
            validate-helper($object, @subs);
        }

    }

    model Transition is Tinky::Transition does WithHelper is table('tinky_transition') is rw {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Tinky::DB::Workflow', column => 'id', require => 'Tinky::DB');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Tinky::DB::Workflow', require => 'Tinky::DB');
        has Int $.from-id       is referencing(model => 'Tinky::DB::State', column => 'id', require => 'Tinky::DB');
        has     $.from          is relationship({  .from-id }, model => 'Tinky::DB::State', require => 'Tinky::DB' );
        has Int $.to-id         is referencing(model => 'Tinky::DB::State', column => 'id', require => 'Tinky::DB');
        has     $.to            is relationship({  .to-id }, model => 'Tinky::DB::State', require => 'Tinky::DB' );
        has Str     $.helper-class      is column(:nullable);

        multi method ACCEPTS(Transition:D $transition --> Bool ) {
            self.id == $transition.id
        }

        my Supplier $supplier;

        method !supplier( --> Supplier ) {
            $supplier //= Supplier.new;
        }

        method supply( --> Supply ) {
            self!supplier.Supply.grep( -> $ ( $t, $o ) { $t.id == self.id } ).map( -> $ ($, $o) { $o } );
        }

        method applied(Object:D $object) {
            self.from.leave($object);
            self.to.enter($object);
            self!supplier.emit([ self, $object ]);
        }

         method validate(Object:D $object --> Promise ) {
            validate-helper($object, ( @.validators, $.helper.defined ?? validate-methods($.helper, $object, TransitionValidator) !! Empty).flat);
        }

        method validate-apply(Object:D $object --> Promise ) {
            my @promises = (self.validate($object), self.from.validate-leave($object), self.to.validate-enter($object));
            Promise.allof(@promises).then( { so all(@promises.map(-> $p { $p.result })) });
        }

    }
}

# vim: ft=raku
