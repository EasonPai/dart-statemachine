library statemachine_test;

import 'dart:async';

import 'package:unittest/unittest.dart';
import 'package:statemachine/statemachine.dart';

void main() {
  group('stream transitions', () {
    var controllerA = new StreamController.broadcast(sync: true);
    var controllerB = new StreamController.broadcast(sync: true);
    var controllerC = new StreamController.broadcast(sync: true);

    var machine = new Machine();

    var stateA = machine.newState('a');
    var stateB = machine.newState('b');
    var stateC = machine.newState('c');

    stateA.onStream(controllerB.stream, (event) => stateB.enter());
    stateA.onStream(controllerC.stream, (event) => stateC.enter());

    stateB.onStream(controllerA.stream, (event) => stateA.enter());
    stateB.onStream(controllerC.stream, (event) => stateC.enter());

    stateC.onStream(controllerA.stream, (event) => stateA.enter());
    stateC.onStream(controllerB.stream, (event) => stateB.enter());

    test('initial state', () {
      machine.start();
      expect(machine.current, stateA);
    });
    test('simple transition', () {
      machine.start();
      controllerB.add('*');
      expect(machine.current, stateB);
    });
    test('double transition', () {
      machine.start();
      controllerB.add('*');
      controllerC.add('*');
      expect(machine.current, stateC);
    });
    test('triple transition', () {
      machine.start();
      controllerB.add('*');
      controllerC.add('*');
      controllerA.add('*');
      expect(machine.current, stateA);
    });
    test('many transitions', () {
      machine.start();
      for (var i = 0; i < 100; i++) {
        controllerB.add('*');
        controllerA.add('*');
      }
      expect(machine.current, stateA);
    });
    test('name', () {
      expect(stateA.toString(), 'State[a]');
      expect(stateB.toString(), 'State[b]');
      expect(stateC.toString(), 'State[c]');
    });
  });
  test('conflicting transitions', () {
    var controller = new StreamController.broadcast(sync: true);

    var machine = new Machine();

    var stateA = machine.newState('a');
    var stateB = machine.newState('b');
    var stateC = machine.newState('c');

    stateA.onStream(controller.stream, (value) => stateB.enter());
    stateA.onStream(controller.stream, (value) => stateC.enter());

    machine.start();
    controller.add('*');
    expect(machine.current, stateB);
  });
  test('future transitions', () {
    var completerB = new Completer();
    var completerC = new Completer();

    var machine = new Machine();

    var stateA = machine.newState('a');
    var stateB = machine.newState('b');
    var stateC = machine.newState('c');

    stateA.onFuture(
        completerB.future,
        expectAsync((value) {
          expect(machine.current, stateA);
          stateB.enter();
        }));
    stateA.onFuture(
        completerC.future,
        (value) => fail('should never be called'));

    machine.start();
    completerB.complete();
  });
  test('timeout transitions', () {
    var machine = new Machine();

    var stateA = machine.newState('a');
    var stateB = machine.newState('b');
    var stateC = machine.newState('c');

    stateA.onTimeout(
        new Duration(milliseconds: 10),
        expectAsync(() {
          expect(machine.current, stateA);
          stateB.enter();
        }));
    stateA.onTimeout(
        new Duration(milliseconds: 20),
        () => fail('should never be called'));
    stateB.onTimeout(
        new Duration(milliseconds: 20),
        () => fail('should never be called'));
    stateB.onTimeout(
        new Duration(milliseconds: 10),
        expectAsync(() {
          expect(machine.current, stateB);
          stateC.enter();
        }));

    machine.start();
  });
  test('start/stop state', () {
    var machine = new Machine();
    var startState = machine.newStartState('a');
    var stopState = machine.newStopState('b');
    expect(machine.current, isNull);
    machine.start();
    expect(machine.current, startState);
    machine.stop();
    expect(machine.current, stopState);
  });
  test('entry/exit transitions', () {
    var log = new List();
    var machine = new Machine();
    var stateA = machine.newState('a')
        ..onEntry(() => log.add('on a'))
        ..onExit(() => log.add('off a'));
    var stateB = machine.newState('b')
        ..onEntry(() => log.add('on b'))
        ..onExit(() => log.add('off b'));
    machine.start();
    stateB.enter();
    expect(log, ['on a', 'off a', 'on b']);
  });
  test('nested machine', () {
    var log = new List();
    var inner = new Machine();
    var innerState = inner.newState('a')
        ..onEntry(() => log.add('inner entry a'))
        ..onExit(() => log.add('inner exit a'));
    var outer = new Machine();
    var outerState = outer.newState('a')
        ..onEntry(() => log.add('outer entry a'))
        ..onExit(() => log.add('outer exit a'))
        ..addNested(inner);
    outer.start();
    expect(log, ['outer entry a', 'inner entry a']);
    outer.stop();
    expect(log, ['outer entry a', 'inner entry a', 'outer exit a', 'inner exit a']);
  });
}
