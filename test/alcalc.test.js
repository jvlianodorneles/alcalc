// test/alcalc.test.js - Comprehensive test suite for Alcalc Engine
const test = require('node:test');
const assert = require('node:assert/strict');
const Engine = require('../src/Engine.js');

test('Basic Arithmetic & Left-to-Right Evaluation', () => {
  // ACL evaluates left to right without precedence: 6/3+2*5 = ((6/3)+2)*5 = (2+2)*5 = 20
  const res1 = Engine.evaluateExpression('6/3+2*5');
  assert.equal(res1.kind, 'answer');
  assert.equal(res1.text, '20');

  // Explicit grouping
  const res2 = Engine.evaluateExpression('(6/3)+(2*5)');
  assert.equal(res2.kind, 'answer');
  assert.equal(res2.text, '12');

  // Negative numbers with _ prefix
  const res3 = Engine.evaluateExpression('_5 + 10');
  assert.equal(res3.kind, 'answer');
  assert.equal(res3.text, '5');

  // Power with TOTHE
  const res4 = Engine.evaluateExpression('2 TOTHE 8');
  assert.equal(res4.kind, 'answer');
  assert.equal(res4.text, '256');

  // Modulo
  const res5 = Engine.evaluateExpression('17 MOD 5');
  assert.equal(res5.kind, 'answer');
  assert.equal(res5.text, '2');
});

test('Clumps, Sequences & Fold (INSERT)', () => {
  // Range generation: 1..10
  const res1 = Engine.evaluateExpression('1..5');
  assert.equal(res1.kind, 'answer');
  assert.equal(res1.text, '1 2 3 4 5');

  // Sum fold: 1..100 INSERT +
  const res2 = Engine.evaluateExpression('1..100 INSERT +');
  assert.equal(res2.kind, 'answer');
  assert.equal(res2.text, '5050');

  // Product fold: 1..5 INSERT * = 120
  const res3 = Engine.evaluateExpression('1..5 INSERT *');
  assert.equal(res3.kind, 'answer');
  assert.equal(res3.text, '120');

  // Vectorized addition of two clumps
  const res4 = Engine.evaluateExpression('(1 2 3) + (10 20 30)');
  assert.equal(res4.kind, 'answer');
  assert.equal(res4.text, '11 22 33');

  // Left-to-right clump alignment
  const res4b = Engine.evaluateExpression('1 2 3 + 10 20 30');
  assert.equal(res4b.kind, 'answer');
  assert.equal(res4b.text, '11 12 13 20 30');

  // Scalar to vector addition
  const res5 = Engine.evaluateExpression('1 2 3 + 10');
  assert.equal(res5.kind, 'answer');
  assert.equal(res5.text, '11 12 13');
});

test('Monadic Operations', () => {
  // SUM, PROD, MEAN, MEDIAN, NORM
  assert.equal(Engine.evaluateExpression('10 20 30 SUM').text, '60');
  assert.equal(Engine.evaluateExpression('2 3 4 PROD').text, '24');
  assert.equal(Engine.evaluateExpression('10 20 30 MEAN').text, '20');
  assert.equal(Engine.evaluateExpression('10 50 20 30 MEDIAN').text, '25');
  assert.equal(Engine.evaluateExpression('3 4 NORM').text, '5');

  // PRIMES & PRIME
  assert.equal(Engine.evaluateExpression('17 PRIME').text, '1');
  assert.equal(Engine.evaluateExpression('18 PRIME').text, '0');
  assert.equal(Engine.evaluateExpression('1..20 PRIMES').text, '2 3 5 7 11 13 17 19');

  // GCD & LCM
  assert.equal(Engine.evaluateExpression('12 18 GCD').text, '6');
  assert.equal(Engine.evaluateExpression('4 6 10 LCM').text, '60');

  // SORT & REVERSE
  assert.equal(Engine.evaluateExpression('5 1 4 2 3 SORT').text, '1 2 3 4 5');
  assert.equal(Engine.evaluateExpression('1 2 3 4 5 REVERSE').text, '5 4 3 2 1');

  // FACT, SQRT, ABS
  assert.equal(Engine.evaluateExpression('5 FACT').text, '120');
  assert.equal(Engine.evaluateExpression('64 SQRT').text, '8');
  assert.equal(Engine.evaluateExpression('_42 ABS').text, '42');
});

test('Text & Strings', () => {
  // String length
  assert.equal(Engine.evaluateExpression('"hello world" LENGTH').text, '11');

  // String reversal via index slice
  assert.equal(Engine.evaluateExpression('"stressed" [8..1]').text, 'desserts');

  // ASCII conversions (NUMBER & LETTER)
  assert.equal(Engine.evaluateExpression('"A" NUMBER').text, '65');
  assert.equal(Engine.evaluateExpression('65 LETTER').text, 'A');

  // Hex conversion
  assert.equal(Engine.evaluateExpression('"FF" FROMHEX').text, '255');
  assert.equal(Engine.evaluateExpression('255 HEX').text, 'FF');
});

test('Variables & Assignment', () => {
  const initialVars = {};
  const res1 = Engine.evaluateExpression('10 : x', initialVars);
  assert.equal(res1.kind, 'silent');
  assert.equal(res1.machine.vars.x.items[0].v, 10);

  const res2 = Engine.evaluateExpression('x * 5', res1.machine.vars);
  assert.equal(res2.kind, 'answer');
  assert.equal(res2.text, '50');

  // PLACES setting
  const res3 = Engine.evaluateExpression('2 : PLACES');
  assert.equal(res3.machine.places, 2);
  const res4 = Engine.evaluateExpression('PI', {}, 2);
  assert.equal(res4.text, '3.14');
});

test('Step-by-Step Tracing (explainExpression)', () => {
  const res = Engine.explainExpression('6/3+2*5');
  assert.equal(res.kind, 'answer');
  assert.equal(res.text, '20');
  assert.ok(res.steps.length > 0);
});

test('Smart Error Assistance', () => {
  const res = Engine.evaluateExpression('(5 + 2');
  assert.equal(res.kind, 'error');
  const tip = Engine.getSmartErrorTip(res.text, '(5 + 2');
  assert.ok(tip);
  assert.ok(tip.tip.includes('parenthesis'));
  assert.equal(tip.suggestedFix, '(5 + 2)');
});

test('Macro Expansion', () => {
  const macros = {
    fahrenheit: 'x - 32 * 5 / 9'
  };
  const { expandedExpr } = Engine.expandMacros(macros, 'fahrenheit');
  assert.equal(expandedExpr, '(x - 32 * 5 / 9)');

  const res = Engine.evaluateExpression(expandedExpr, { x: 100 });
  assert.equal(res.kind, 'answer');
  assert.equal(res.text, '37.7778');
});
