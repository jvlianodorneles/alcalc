// Engine.js - Complete Apple Calculator Language (ACL) Engine
// Supports numbers, vectors/clumps, strings, monads, dyads, fold (INSERT),
// indexing ([ ]), variable assignment (:), macros, step-by-step explain, and error tips.

class AppleError extends Error {
  constructor(message, isMathError = false) {
    super(message);
    this.name = 'AppleError';
    this.isMathError = isMathError;
  }
}

function oops(msg, isMathError = false) {
  throw new AppleError(msg, isMathError);
}

const DYADIC_WORDS = ['TOTHE', 'MOD', 'MIN', 'MAX', 'AND', 'OR', 'XOR', 'COMB', 'NCR', 'PERM', 'NPR', 'DOT'];
const MONADIC_WORDS = [
  'ARCSIN', 'ARCCOS', 'ARCTAN', 'SIN', 'COS', 'TAN', 'NOT', 'LOG', 'LN',
  'FLOOR', 'CEILING', 'ROUND', 'TRUNCATE', 'PICK', 'LENGTH', 'LEN',
  'ODD', 'EVEN', 'NUMBER', 'LETTER', 'STRING', 'VALUE',
  'ABS', 'SQRT', 'SIGN', 'REVERSE', 'SORT', 'HEX', 'BIN', 'OCT',
  'LCM', 'GCD', 'GCF',
  'SUM', 'PROD', 'PRODUCT', 'MEAN', 'AVG', 'MEDIAN',
  'FACT', 'PRIME', 'PRIMES', 'FROMHEX', 'FROMBIN', 'FROMOCT', 'NORM'
];
const SPECIAL_WORDS = ['PLACES', 'RADIANS', 'PI', 'E', 'ANS'];
const ALL_KEYWORDS = DYADIC_WORDS.concat(MONADIC_WORDS, SPECIAL_WORDS, ['INSERT']);
const SYMBOL_OPS = ['..', '<=', '>=', '<>', '+', '-', '*', '/', '<', '>', '='];
const PAD = {
  '+': 0, '-': 0, '*': 1, '/': 1, 'TOTHE': 1, '..': 1, 'MOD': 0, 'MIN': 0, 'MAX': 0,
  '<': 0, '=': 0, '>': 0, '>=': 0, '<=': 0, '<>': 0, 'AND': 1, 'OR': 0, 'XOR': 0,
  'COMB': 0, 'NCR': 0, 'PERM': 0, 'NPR': 0, 'DOT': 0
};

function num(v) {
  return { items: [{ t: 'n', v: v }] };
}

function chars(s) {
  const o = [];
  for (let i = 0; i < s.length; i++) {
    o.push({ t: 'c', v: s.charAt(i) });
  }
  return { items: o };
}

function clump(items) {
  return { items: items || [] };
}

function hasChars(items) {
  for (let i = 0; i < items.length; i++) {
    if (items[i].t === 'c') return true;
  }
  return false;
}

function asNumber(it) {
  return it.t === 'n' ? it.v : it.v.charCodeAt(0);
}

function concat(a, b) {
  if (!a) return b;
  if (!b) return a;
  if (a.unset && hasChars(b.items)) return clump(b.items.slice());
  if (b.unset && hasChars(a.items)) return clump(a.items.slice());
  return clump(a.items.concat(b.items));
}

function roundHalfEven(v) {
  const f = Math.floor(v);
  const d = v - f;
  if (d > 0.5) return f + 1;
  if (d < 0.5) return f;
  return (f % 2 === 0) ? f : f + 1;
}

function fmtNum(v, places = 4) {
  if (typeof v !== 'number' || v !== v) return 'NOT A NUMBER';
  if (v === Infinity) return 'INFINITY';
  if (v === -Infinity) return '_INFINITY';
  const neg = v < 0;
  const a = Math.abs(v);
  let s;
  const p = places !== null && places !== undefined ? places : 4;
  if (a >= 1e15) {
    s = a.toExponential(Math.max(1, Math.min(p, 15)));
    s = s.replace(/0+e/, 'e').replace(/\.e/, 'e');
    s = s.replace('e+', 'E').replace('e-', 'E_');
  } else {
    s = Number(a.toPrecision(15)).toFixed(Math.min(p, 20));
    if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '');
    if (s === '') s = '0';
  }
  if (neg && parseFloat(s) !== 0) s = '_' + s;
  return s;
}

function render(value, places = 4) {
  if (!value || !value.items) return '';
  let out = '';
  let prev = null;
  for (let i = 0; i < value.items.length; i++) {
    const it = value.items[i];
    if (prev !== null && (it.t === 'n' || prev === 'n')) out += ' ';
    out += (it.t === 'c') ? it.v : fmtNum(it.v, places);
    prev = it.t;
  }
  return out;
}

function isDigit(c) {
  return c >= '0' && c <= '9';
}

function isLetter(c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

function isNameChar(c) {
  return isLetter(c) || isDigit(c);
}

function scanNumber(src, i) {
  const start = i;
  let seenDot = false;
  let digits = 0;
  let c;
  while (i < src.length) {
    c = src.charAt(i);
    if (isDigit(c)) {
      digits++;
      i++;
      continue;
    }
    if (c === '.' && !seenDot) {
      if (src.charAt(i + 1) === '.') break;
      seenDot = true;
      i++;
      continue;
    }
    break;
  }
  if (digits === 0) return null;
  return { text: src.slice(start, i), end: i };
}

function scanName(src, i) {
  const start = i;
  let c;
  let nxt;
  if (!isLetter(src.charAt(i))) return null;
  i++;
  while (i < src.length) {
    c = src.charAt(i);
    if (isNameChar(c)) {
      i++;
      continue;
    }
    nxt = src.charAt(i + 1);
    if ((c === '.' || c === '_') && isNameChar(nxt)) {
      i++;
      continue;
    }
    break;
  }
  return { text: src.slice(start, i), end: i };
}

function tokenize(src) {
  const toks = [];
  let i = 0;
  const n = src.length;
  let c, m, q, s, depth, k, sym, found;

  while (i < n) {
    c = src.charAt(i);
    if (c === ' ' || c === '\t' || c === '\r' || c === '\n') {
      i++;
      continue;
    }
    if (c === '{') {
      depth = 1;
      i++;
      while (i < n && depth > 0) {
        if (src.charAt(i) === '{') depth++;
        else if (src.charAt(i) === '}') depth--;
        i++;
      }
      continue;
    }
    if (c === '}') oops('THERE IS A "}" WITH NO "{" IN FRONT OF IT');
    if (c === '"' || c === "'") {
      q = c;
      i++;
      s = '';
      while (i < n && src.charAt(i) !== q) {
        s += src.charAt(i);
        i++;
      }
      if (i >= n) oops('THAT QUOTATION IS NEVER CLOSED');
      i++;
      toks.push({ k: 'str', v: s });
      continue;
    }
    if (c === '_') {
      m = scanNumber(src, i + 1);
      if (!m) oops('AN UNDERSCORE MUST BE FOLLOWED BY A NUMBER, AS IN _45.4');
      toks.push({ k: 'num', v: -parseFloat(m.text) });
      i = m.end;
      continue;
    }
    if (isDigit(c) || (c === '.' && isDigit(src.charAt(i + 1)))) {
      m = scanNumber(src, i);
      if (m) {
        toks.push({ k: 'num', v: parseFloat(m.text) });
        i = m.end;
        continue;
      }
    }
    if (isLetter(c)) {
      m = scanName(src, i);
      i = m.end;
      if (m.text === 'INSERT') {
        toks.push({ k: 'insert' });
        continue;
      }
      if (DYADIC_WORDS.indexOf(m.text) >= 0) {
        toks.push({ k: 'op', v: m.text });
        continue;
      }
      if (MONADIC_WORDS.indexOf(m.text) >= 0) {
        toks.push({ k: 'mon', v: m.text });
        continue;
      }
      if (SPECIAL_WORDS.indexOf(m.text) >= 0) {
        toks.push({ k: 'special', v: m.text });
        continue;
      }
      if (m.text.length > 1 && m.text === m.text.toUpperCase() && /[A-Z]/.test(m.text)) {
        oops('I DO NOT KNOW THE WORD "' + m.text + '"');
      }
      toks.push({ k: 'name', v: m.text });
      continue;
    }
    found = false;
    for (k = 0; k < SYMBOL_OPS.length; k++) {
      sym = SYMBOL_OPS[k];
      if (src.substr(i, sym.length) === sym) {
        toks.push({ k: 'op', v: sym });
        i += sym.length;
        found = true;
        break;
      }
    }
    if (found) continue;
    if (c === ':') {
      toks.push({ k: 'colon' });
      i++;
      continue;
    }
    if ('()[]'.indexOf(c) >= 0) {
      toks.push({ k: c });
      i++;
      continue;
    }
    oops('I CANNOT MAKE SENSE OF "' + c + '"');
  }
  return toks;
}

class Machine {
  constructor(initialVars = {}, places = 4, radians = 1) {
    this.vars = Object.assign({}, initialVars);
    this.places = places;
    this.radians = radians;
  }

  reset() {
    this.vars = {};
    this.places = 4;
    this.radians = 1;
  }

  lookup(name) {
    if (Object.prototype.hasOwnProperty.call(this.vars, name)) {
      let val = this.vars[name];
      if (typeof val === 'string') {
        try {
          val = JSON.parse(val);
        } catch (_) {}
      }
      if (val && Array.isArray(val.items)) {
        return clump(val.items.slice());
      }
      if (typeof val === 'number') {
        return num(val);
      }
    }
    return { items: [{ t: 'n', v: 0 }], unset: true };
  }

  special(word) {
    if (word === 'PI') return num(Math.PI);
    if (word === 'E') return num(Math.E);
    if (word === 'PLACES') return num(this.places);
    if (word === 'RADIANS') return num(this.radians);
    if (word === 'ANS') return this.lookup('ANS');
    return num(0);
  }
}

function pairOp(op, x, y, m) {
  const a = asNumber(x);
  const b = asNumber(y);
  let lo, hi, out, i, t;
  switch (op) {
    case '+': return [{ t: 'n', v: a + b }];
    case '-': return [{ t: 'n', v: a - b }];
    case '*': return [{ t: 'n', v: a * b }];
    case '/':
      if (b === 0) oops("YOU MUSTN'T DIVIDE BY ZERO", true);
      return [{ t: 'n', v: a / b }];
    case 'MOD':
      if (b === 0) oops("YOU MUSTN'T DIVIDE BY ZERO", true);
      return [{ t: 'n', v: a - b * Math.floor(a / b) }];
    case 'TOTHE':
      t = Math.pow(a, b);
      if (t !== t) oops('I CANNOT RAISE ' + fmtNum(a, m.places) + ' TO THE POWER ' + fmtNum(b, m.places), true);
      return [{ t: 'n', v: t }];
    case 'MIN': return [{ t: 'n', v: Math.min(a, b) }];
    case 'MAX': return [{ t: 'n', v: Math.max(a, b) }];
    case '<': return [{ t: 'n', v: a < b ? 1 : 0 }];
    case '>': return [{ t: 'n', v: a > b ? 1 : 0 }];
    case '=': return [{ t: 'n', v: a === b ? 1 : 0 }];
    case '<=': return [{ t: 'n', v: a <= b ? 1 : 0 }];
    case '>=': return [{ t: 'n', v: a >= b ? 1 : 0 }];
    case '<>': return [{ t: 'n', v: a !== b ? 1 : 0 }];
    case 'AND': return [{ t: 'n', v: (a | 0) & (b | 0) }];
    case 'OR': return [{ t: 'n', v: (a | 0) | (b | 0) }];
    case 'XOR': return [{ t: 'n', v: (a | 0) ^ (b | 0) }];
    case 'COMB':
    case 'NCR':
      return [{ t: 'n', v: nCr(a, b) }];
    case 'PERM':
    case 'NPR':
      return [{ t: 'n', v: nPr(a, b) }];
    case '..':
      lo = Math.trunc(a);
      hi = Math.trunc(b);
      if (Math.abs(hi - lo) > 20000) oops('THAT RANGE IS TOO LONG FOR ME TO HOLD', true);
      out = [];
      if (lo <= hi) {
        for (i = lo; i <= hi; i++) out.push({ t: 'n', v: i });
      } else {
        for (i = lo; i >= hi; i--) out.push({ t: 'n', v: i });
      }
      return out;
    default:
      oops('I DO NOT KNOW THE OPERATION "' + op + '"');
  }
}

function padItem(op, sample) {
  if (sample && sample.t === 'c') return { t: 'c', v: '\u0000' };
  const p = PAD[op];
  return { t: 'n', v: (p === undefined ? 0 : p) };
}

function dyad(op, A, B, m) {
  const a = A.items;
  const b = B.items;
  let la = a.length;
  let lb = b.length;
  let pa = a;
  let pb = b;
  let L, i, r;
  if (la === 0 && lb === 0) return clump([]);
  if (la === 0) { pa = [padItem(op, b[0])]; la = 1; }
  if (lb === 0) { pb = [padItem(op, a[0])]; lb = 1; }
  if (la === 1 && lb > 1) { pa = []; for (i = 0; i < lb; i++) pa.push(a[0]); }
  else if (lb === 1 && la > 1) { pb = []; for (i = 0; i < la; i++) pb.push(b[0]); }
  else if (la !== lb) {
    L = Math.max(la, lb);
    pa = pa.slice(); pb = pb.slice();
    while (pa.length < L) pa.push(padItem(op, a[a.length - 1]));
    while (pb.length < L) pb.push(padItem(op, b[b.length - 1]));
  }
  if (op === 'DOT') {
    let sum = 0;
    for (i = 0; i < pa.length; i++) {
      sum += asNumber(pa[i]) * asNumber(pb[i]);
    }
    return num(sum);
  }
  const out = [];
  for (i = 0; i < pa.length; i++) {
    r = pairOp(op, pa[i], pb[i], m);
    out.push.apply(out, r);
  }
  return clump(out);
}

function toRad(v, m) { return m.radians ? v : v * Math.PI / 180; }
function fromRad(v, m) { return m.radians ? v : v * 180 / Math.PI; }

function isPrime(n) {
  if (typeof n !== 'number' || !Number.isInteger(n) || n <= 1) return false;
  if (n <= 3) return true;
  if (n % 2 === 0 || n % 3 === 0) return false;
  for (let i = 5; i * i <= n; i += 6) {
    if (n % i === 0 || n % (i + 2) === 0) return false;
  }
  return true;
}

function nCr(n, r) {
  n = Math.trunc(n);
  r = Math.trunc(r);
  if (r < 0 || r > n || n < 0) return 0;
  if (r === 0 || r === n) return 1;
  if (r > n / 2) r = n - r;
  let res = 1;
  for (let i = 1; i <= r; i++) {
    res = Math.round((res * (n - r + i)) / i);
  }
  return res;
}

function nPr(n, r) {
  n = Math.trunc(n);
  r = Math.trunc(r);
  if (r < 0 || r > n || n < 0) return 0;
  let res = 1;
  for (let i = 0; i < r; i++) {
    res *= (n - i);
  }
  return res;
}

function gcd2(a, b) {
  let x = Math.abs(Math.trunc(a));
  let y = Math.abs(Math.trunc(b));
  while (y) {
    const t = y;
    y = x % y;
    x = t;
  }
  return x;
}

function lcm2(a, b) {
  const x = Math.abs(Math.trunc(a));
  const y = Math.abs(Math.trunc(b));
  if (x === 0 || y === 0) return 0;
  return (x / gcd2(x, y)) * y;
}

function monad(word, V, m) {
  const items = V.items;
  const out = [];
  let i, x, v, code, txt;
  if (word === 'LENGTH' || word === 'LEN') return num(items.length);
  if (word === 'PICK') {
    if (!items.length) oops('THERE IS NOTHING HERE TO PICK FROM', true);
    return clump([items[Math.floor(Math.random() * items.length)]]);
  }
  if (word === 'VALUE') {
    txt = '';
    for (i = 0; i < items.length; i++) {
      txt += items[i].t === 'c' ? items[i].v : fmtNum(items[i].v, m.places);
    }
    txt = txt.replace(/_/g, '-').trim();
    v = parseFloat(txt);
    return num(v !== v ? 0 : v);
  }
  if (word === 'REVERSE') {
    return clump(items.slice().reverse());
  }
  if (word === 'SORT') {
    const sorted = items.slice().sort((a, b) => asNumber(a) - asNumber(b));
    return clump(sorted);
  }
  if (word === 'PRIMES') {
    const primes = items.filter(x => isPrime(asNumber(x)));
    return clump(primes);
  }
  if (word === 'LCM' || word === 'GCD' || word === 'GCF') {
    if (!items.length) return num(0);
    let res = Math.abs(Math.trunc(asNumber(items[0])));
    for (i = 1; i < items.length; i++) {
      const val = asNumber(items[i]);
      if (word === 'LCM') {
        res = lcm2(res, val);
      } else {
        res = gcd2(res, val);
      }
    }
    return num(res);
  }
  if (word === 'SUM') {
    let s = 0;
    for (i = 0; i < items.length; i++) s += asNumber(items[i]);
    return num(s);
  }
  if (word === 'PROD' || word === 'PRODUCT') {
    if (!items.length) return num(1);
    let p = 1;
    for (i = 0; i < items.length; i++) p *= asNumber(items[i]);
    return num(p);
  }
  if (word === 'MEAN' || word === 'AVG') {
    if (!items.length) return num(0);
    let s = 0;
    for (i = 0; i < items.length; i++) s += asNumber(items[i]);
    return num(s / items.length);
  }
  if (word === 'MEDIAN') {
    if (!items.length) return num(0);
    const nums = items.map(asNumber).sort((a, b) => a - b);
    const mid = Math.floor(nums.length / 2);
    if (nums.length % 2 !== 0) return num(nums[mid]);
    return num((nums[mid - 1] + nums[mid]) / 2);
  }
  if (word === 'NORM') {
    let sumSq = 0;
    for (i = 0; i < items.length; i++) {
      const val = asNumber(items[i]);
      sumSq += val * val;
    }
    return num(Math.sqrt(sumSq));
  }
  if (word === 'FROMHEX' || word === 'FROMBIN' || word === 'FROMOCT') {
    const base = word === 'FROMHEX' ? 16 : word === 'FROMBIN' ? 2 : 8;
    txt = '';
    for (i = 0; i < items.length; i++) {
      txt += items[i].t === 'c' ? items[i].v : String(items[i].v);
    }
    const parsed = parseInt(txt.trim(), base);
    if (isNaN(parsed)) oops('INVALID NUMBER FOR BASE CONVERSION', true);
    return num(parsed);
  }
  if (word === 'NUMBER' && items.length === 0) return num(0);
  for (i = 0; i < items.length; i++) {
    x = items[i];
    switch (word) {
      case 'FACT':
        v = Math.trunc(asNumber(x));
        if (v < 0) oops('I CANNOT TAKE THE FACTORIAL OF A NEGATIVE NUMBER', true);
        if (v > 170) oops('FACTORIAL RESULT IS TOO LARGE', true);
        let f = 1;
        for (let k = 2; k <= v; k++) f *= k;
        out.push({ t: 'n', v: f });
        break;
      case 'PRIME':
        v = Math.trunc(asNumber(x));
        out.push({ t: 'n', v: isPrime(v) ? 1 : 0 });
        break;
      case 'SIN': out.push({ t: 'n', v: Math.sin(toRad(asNumber(x), m)) }); break;
      case 'COS': out.push({ t: 'n', v: Math.cos(toRad(asNumber(x), m)) }); break;
      case 'TAN': out.push({ t: 'n', v: Math.tan(toRad(asNumber(x), m)) }); break;
      case 'ARCSIN':
        v = asNumber(x);
        if (v < -1 || v > 1) oops('ARCSIN ONLY LIKES NUMBERS FROM _1 TO 1', true);
        out.push({ t: 'n', v: fromRad(Math.asin(v), m) }); break;
      case 'ARCCOS':
        v = asNumber(x);
        if (v < -1 || v > 1) oops('ARCCOS ONLY LIKES NUMBERS FROM _1 TO 1', true);
        out.push({ t: 'n', v: fromRad(Math.acos(v), m) }); break;
      case 'ARCTAN': out.push({ t: 'n', v: fromRad(Math.atan(asNumber(x)), m) }); break;
      case 'LOG':
        v = asNumber(x);
        if (v <= 0) oops('I CANNOT TAKE THE LOGARITHM OF A NUMBER THAT SMALL', true);
        out.push({ t: 'n', v: Math.log(v) / Math.LN10 }); break;
      case 'LN':
        v = asNumber(x);
        if (v <= 0) oops('I CANNOT TAKE THE LOGARITHM OF A NUMBER THAT SMALL', true);
        out.push({ t: 'n', v: Math.log(v) }); break;
      case 'NOT': out.push({ t: 'n', v: 1 - Math.trunc(asNumber(x)) }); break;
      case 'FLOOR': out.push({ t: 'n', v: Math.floor(asNumber(x)) }); break;
      case 'CEILING': out.push({ t: 'n', v: Math.ceil(asNumber(x)) }); break;
      case 'ROUND': out.push({ t: 'n', v: roundHalfEven(asNumber(x)) }); break;
      case 'TRUNCATE': out.push({ t: 'n', v: Math.trunc(asNumber(x)) }); break;
      case 'ABS': out.push({ t: 'n', v: Math.abs(asNumber(x)) }); break;
      case 'SQRT':
        v = asNumber(x);
        if (v < 0) oops('I CANNOT TAKE THE SQUARE ROOT OF A NEGATIVE NUMBER', true);
        out.push({ t: 'n', v: Math.sqrt(v) });
        break;
      case 'SIGN': out.push({ t: 'n', v: Math.sign(asNumber(x)) }); break;
      case 'HEX':
        txt = Math.trunc(asNumber(x)).toString(16).toUpperCase();
        for (v = 0; v < txt.length; v++) out.push({ t: 'c', v: txt.charAt(v) });
        break;
      case 'BIN':
        txt = Math.trunc(asNumber(x)).toString(2);
        for (v = 0; v < txt.length; v++) out.push({ t: 'c', v: txt.charAt(v) });
        break;
      case 'OCT':
        txt = Math.trunc(asNumber(x)).toString(8);
        for (v = 0; v < txt.length; v++) out.push({ t: 'c', v: txt.charAt(v) });
        break;
      case 'ODD': out.push({ t: 'n', v: Math.abs(Math.trunc(asNumber(x))) % 2 === 1 ? 1 : 0 }); break;
      case 'EVEN': out.push({ t: 'n', v: Math.abs(Math.trunc(asNumber(x))) % 2 === 0 ? 1 : 0 }); break;
      case 'NUMBER': out.push({ t: 'n', v: asNumber(x) }); break;
      case 'LETTER':
        code = Math.trunc(asNumber(x));
        if (code > 0 && code < 1114112) out.push({ t: 'c', v: String.fromCodePoint(code) });
        break;
      case 'STRING':
        if (x.t === 'c') { out.push(x); } else {
          txt = fmtNum(x.v, m.places);
          for (v = 0; v < txt.length; v++) out.push({ t: 'c', v: txt.charAt(v) });
        }
        break;
      default:
        oops('I DO NOT KNOW THE OPERATION "' + word + '"');
    }
  }
  return clump(out);
}

function describe(tok) {
  if (!tok) return 'THE END OF THE LINE';
  if (tok.k === 'num') return String(tok.v);
  if (tok.k === 'str') return '"' + tok.v + '"';
  if (tok.k === 'colon') return ':';
  if (tok.k === 'insert') return 'INSERT';
  if (tok.v !== undefined) return String(tok.v);
  return tok.k;
}

const STARTERS = { 'num': 1, 'str': 1, 'name': 1, 'special': 1, '(': 1 };

function formatStepVal(val, places = 4, maxLen = 35) {
  if (!val) return '';
  let s = render(val, places);
  if (s.length > maxLen) {
    s = s.substring(0, maxLen - 3) + '...';
  }
  return s;
}

class Parser {
  constructor(toks, m, tracing = false) {
    this.t = toks;
    this.i = 0;
    this.m = m;
    this.tracing = tracing;
    this.steps = [];
  }

  peek() { return this.t[this.i] || null; }
  next() { return this.t[this.i++] || null; }

  element(why) {
    const tok = this.next();
    let v;
    if (!tok) oops('I EXPECTED SOMETHING AFTER "' + why + '" BUT THE LINE ENDED');
    switch (tok.k) {
      case 'num': return num(tok.v);
      case 'str': return chars(tok.v);
      case 'name': return this.m.lookup(tok.v);
      case 'special': return this.m.special(tok.v);
      case '(':
        v = this.expression();
        if (!this.peek() || this.peek().k !== ')') oops('A PARENTHESIS IS NEVER CLOSED');
        this.next();
        return v.value;
      default:
        oops('I EXPECTED A NUMBER OR A NAME AFTER "' + why + '", NOT "' + describe(tok) + '"');
    }
  }

  expression() {
    let acc = null;
    let tok, bareSpecial = null, assigned = false, rhs, idx, opTok, val, after;
    const m = this.m;

    for (; ;) {
      tok = this.peek();
      if (!tok || tok.k === ')' || tok.k === ']') break;
      if (STARTERS[tok.k]) {
        bareSpecial = (acc === null && tok.k === 'special' &&
          (tok.v === 'PLACES' || tok.v === 'RADIANS')) ? tok.v : null;
        val = this.element('the start of the line');
        acc = concat(acc, val);
        assigned = false;
        continue;
      }
      if (tok.k === '[') {
        if (acc === null) oops('A "[" NEEDS A CLUMP TO ITS LEFT');
        this.next();
        idx = this.expression();
        if (!this.peek() || this.peek().k !== ']') oops('A BRACKET IS NEVER CLOSED');
        this.next();
        if (this.tracing) {
          const prevStr = formatStepVal(acc, m.places);
          acc = select(acc, idx.value);
          this.steps.push({
            expr: `${prevStr}[${formatStepVal(idx.value, m.places)}]`,
            result: formatStepVal(acc, m.places),
          });
        } else {
          acc = select(acc, idx.value);
        }
        bareSpecial = null;
        assigned = false;
        continue;
      }
      if (tok.k === 'mon') {
        if (acc === null) oops(tok.v + ' WANTS A CLUMP TO ITS LEFT');
        this.next();
        if (this.tracing) {
          const prevStr = formatStepVal(acc, m.places);
          acc = monad(tok.v, acc, m);
          this.steps.push({
            expr: `${prevStr} ${tok.v}`,
            result: formatStepVal(acc, m.places),
          });
        } else {
          acc = monad(tok.v, acc, m);
        }
        bareSpecial = null;
        assigned = false;
        continue;
      }
      if (tok.k === 'insert') {
        if (acc === null) oops('INSERT WANTS A CLUMP TO ITS LEFT');
        this.next();
        opTok = this.next();
        if (!opTok || opTok.k !== 'op') oops('INSERT MUST BE FOLLOWED BY AN OPERATION LIKE + OR MAX');
        if (this.tracing) {
          const prevStr = formatStepVal(acc, m.places);
          acc = fold(opTok.v, acc, m);
          this.steps.push({
            expr: `${prevStr} INSERT ${opTok.v}`,
            result: formatStepVal(acc, m.places),
          });
        } else {
          acc = fold(opTok.v, acc, m);
        }
        bareSpecial = null;
        assigned = false;
        continue;
      }
      if (tok.k === 'colon') {
        this.next();
        after = this.peek();
        if (after && (after.k === 'name' || after.k === 'special')) {
          this.next();
          assign(m, after.v, acc, after.k === 'special');
          if (this.tracing) {
            this.steps.push({
              expr: `${formatStepVal(acc, m.places)} : ${after.v}`,
              result: `Stored variable/setting ${after.v}`,
            });
          }
          assigned = true;
          bareSpecial = null;
          continue;
        }
        if (after && (after.k === 'mon' || after.k === 'insert' ||
          (after.k === 'op' && /^[A-Z]+$/.test(String(after.v))))) {
          oops('YOU MAY NOT USE THE KEYWORD ' + describe(after) + ' AS A NAME');
        }
        if (bareSpecial) {
          val = this.element(':');
          assign(m, bareSpecial, val, true);
          if (this.tracing) {
            this.steps.push({
              expr: `${bareSpecial} : ${formatStepVal(val, m.places)}`,
              result: `Stored setting ${bareSpecial}`,
            });
          }
          acc = val;
          assigned = true;
          bareSpecial = null;
          continue;
        }
        oops('THE COLON WANTS A NAME ON ITS RIGHT, AS IN  5: fingers');
      }
      if (tok.k === 'op') {
        if (acc === null) oops('I EXPECTED SOMETHING BEFORE "' + tok.v + '"');
        this.next();
        if (this.tracing) {
          const prevStr = formatStepVal(acc, m.places);
          rhs = this.element(tok.v);
          const rhsStr = formatStepVal(rhs, m.places);
          acc = dyad(tok.v, acc, rhs, m);
          this.steps.push({
            expr: `${prevStr} ${tok.v} ${rhsStr}`,
            result: formatStepVal(acc, m.places),
          });
        } else {
          rhs = this.element(tok.v);
          acc = dyad(tok.v, acc, rhs, m);
        }
        bareSpecial = null;
        assigned = false;
        continue;
      }
      oops('I CANNOT MAKE SENSE OF "' + describe(tok) + '"');
    }
    if (acc === null) return { value: clump([]), assigned: false, empty: true };
    return { value: acc, assigned: assigned, empty: false };
  }
}

function assign(m, name, value, isSpecial) {
  let v;
  if (!value) oops('THERE IS NOTHING TO THE LEFT OF THE COLON TO STORE');
  if (isSpecial || SPECIAL_WORDS.indexOf(name) >= 0) {
    if (name === 'PI' || name === 'E') oops('PI AND E ARE CONSTANTS AND CANNOT BE CHANGED', true);
    if (name === 'ANS') {
      m.vars['ANS'] = clump(value.items.slice());
      return;
    }
    v = value.items.length ? asNumber(value.items[0]) : 0;
    if (name === 'PLACES') {
      v = Math.trunc(v);
      if (v < 0 || v > 18) oops('PLACES MUST BE A WHOLE NUMBER FROM 0 TO 18', true);
      m.places = v;
    } else {
      m.radians = v ? 1 : 0;
    }
    return;
  }
  if (ALL_KEYWORDS.indexOf(name) >= 0) oops('YOU MAY NOT USE THE KEYWORD ' + name + ' AS A NAME');
  m.vars[name] = clump(value.items.slice());
}

function fold(op, V, m) {
  const items = V.items;
  let acc, i;
  if (!items.length) return num(PAD[op] === undefined ? 0 : PAD[op]);
  acc = clump([items[0]]);
  for (i = 1; i < items.length; i++) acc = dyad(op, acc, clump([items[i]]), m);
  return acc;
}

function select(source, index) {
  const out = [];
  let i, k;
  const isText = hasChars(source.items);
  for (i = 0; i < index.items.length; i++) {
    k = Math.trunc(asNumber(index.items[i]));
    if (k >= 1 && k <= source.items.length) out.push(source.items[k - 1]);
    else if (!isText) out.push({ t: 'n', v: 0 });
  }
  return clump(out);
}

function evaluateExpression(expr, initialVars = {}, places = 4, radians = 1) {
  const machine = new Machine(initialVars, places, radians);
  try {
    const toks = tokenize(expr);
    if (!toks.length) {
      return { kind: 'silent', machine };
    }
    const parser = new Parser(toks, machine);
    const res = parser.expression();
    if (parser.peek()) oops('I DO NOT KNOW WHAT "' + describe(parser.peek()) + '" IS DOING THERE');
    if (res.assigned || res.empty) {
      return { kind: 'silent', machine, value: res.value };
    }
    return { kind: 'answer', text: render(res.value, machine.places), value: res.value, machine };
  } catch (e) {
    if (e instanceof AppleError) {
      return { kind: 'error', text: e.message, isAppleError: true, isMathError: e.isMathError, machine };
    }
    return { kind: 'error', text: 'SOMETHING WENT WRONG: ' + (e?.message || e), isAppleError: false, isMathError: false, machine };
  }
}

function explainExpression(expr, initialVars = {}, places = 4, radians = 1) {
  const machine = new Machine(initialVars, places, radians);
  try {
    const toks = tokenize(expr);
    if (!toks.length) {
      return { kind: 'silent', machine, steps: [] };
    }
    const parser = new Parser(toks, machine, true);
    const res = parser.expression();
    if (parser.peek()) oops('I DO NOT KNOW WHAT "' + describe(parser.peek()) + '" IS DOING THERE');
    if (res.assigned || res.empty) {
      return { kind: 'silent', machine, value: res.value, steps: parser.steps };
    }
    return { kind: 'answer', text: render(res.value, machine.places), value: res.value, steps: parser.steps, machine };
  } catch (e) {
    if (e instanceof AppleError) {
      return { kind: 'error', text: e.message, isAppleError: true, isMathError: e.isMathError, machine };
    }
    return { kind: 'error', text: 'SOMETHING WENT WRONG: ' + (e?.message || e), isAppleError: false, isMathError: false, machine };
  }
}

function getSmartErrorTip(errMessage, expr) {
  if (!errMessage || typeof errMessage !== 'string') return null;
  const msgUpper = errMessage.toUpperCase();

  if (msgUpper.includes('PARENTHESIS IS NEVER CLOSED')) {
    return {
      tip: "You opened a parenthesis `(` that was never closed. Add a matching `)`.",
      suggestedFix: `${expr})`,
    };
  }
  if (msgUpper.includes('UNDERSCORE MUST BE FOLLOWED BY A NUMBER')) {
    return {
      tip: "Negative numbers require `_` attached directly to the digits (e.g. `_45.4` instead of `_ 45.4`).",
      suggestedFix: expr.replace(/_\s+/g, '_'),
    };
  }
  if (msgUpper.includes('QUOTATION IS NEVER CLOSED')) {
    return {
      tip: "A string quotation mark (`\"` or `'`) was not closed.",
      suggestedFix: `${expr}"`,
    };
  }
  if (msgUpper.includes("DIVIDE BY ZERO")) {
    return {
      tip: "Division by zero occurred. Variables default to 0 if unset in ACL.",
      suggestedFix: null,
    };
  }
  if (msgUpper.includes('BRACKET IS NEVER CLOSED')) {
    return {
      tip: "You opened an index bracket `[` that was never closed. Add a matching `]`.",
      suggestedFix: `${expr}]`,
    };
  }
  if (msgUpper.includes('NEEDS A CLUMP TO ITS LEFT')) {
    return {
      tip: "Index selection `[ ]` must be placed directly after a clump (e.g. `(10 20 30)[2]`).",
      suggestedFix: `(${expr})[1]`,
    };
  }
  if (msgUpper.includes('COLON WANTS A NAME')) {
    return {
      tip: "Variable assignment requires a name to the right of `:` (e.g. `5: fingers`).",
      suggestedFix: `${expr} my_var`,
    };
  }
  if (msgUpper.includes('THERE IS A "}" WITH NO "{"')) {
    return {
      tip: "Found a closing comment brace `}` without an opening `{`.",
      suggestedFix: null,
    };
  }
  if (msgUpper.includes('I DO NOT KNOW THE WORD')) {
    return {
      tip: "Check the spelling of your operator or function name. See the Cheatsheet tab for full reference.",
      suggestedFix: null,
    };
  }
  return null;
}

function expandMacros(macrosMap, expr) {
  if (!macrosMap) return { expandedExpr: expr, usedMacros: [] };
  const macroKeys = Object.keys(macrosMap);
  if (macroKeys.length === 0) return { expandedExpr: expr, usedMacros: [] };

  let expanded = expr;
  const used = [];
  for (const name of macroKeys) {
    const regex = new RegExp(`\\b${name}\\b`, 'g');
    if (regex.test(expanded)) {
      expanded = expanded.replace(regex, `(${macrosMap[name]})`);
      used.push(name);
    }
  }
  return { expandedExpr: expanded, usedMacros: used };
}

const SAMPLE_CATEGORIES = {
  basic: {
    name: 'Basic & Chain Calculations',
    items: [
      { title: 'Left-to-Right Chain Calculation (1979 Primer)', expr: '6/3+2*5' },
      { title: 'Sequential Operations without Operator Precedence', expr: '55/11+1+12/6*2-3' },
      { title: 'Explicit Sub-expression Grouping via Parentheses', expr: '(6/3)+(2*5)' },
      { title: 'Golden Ratio Computation', desc: 'phi = (sqrt(5) + 1) / 2', expr: '5 TOTHE .5 + 1 / 2' },
    ],
  },
  clumps: {
    name: 'Clumps & Sequences',
    items: [
      { title: 'Scalar Multiplication over Integer Sequence', expr: '1..9 *13' },
      { title: 'Fahrenheit to Celsius Multi-Value Vectorization', expr: '32 50 100 212 -32*5/9' },
      { title: 'Summation of Annual Monthly Day Count Vector', expr: '31 28 31 30 31 30 31 31 30 31 30 31 INSERT +' },
      { title: 'Summation of Sequential Integers (1 to 100)', expr: '1..100 INSERT +' },
      { title: 'Left-to-Right Clump Element Alignment', expr: '1 2 3 4+4 3 2 1' },
      { title: 'Constant Multiplication across Sequence', expr: 'PI * 1..4' },
      { title: 'Exponential Sequence Generation (2^N)', expr: '2 TOTHE (1..16)' },
      { title: 'Compound Interest Timeline (10 Years @ 5%)', expr: '1000 * (1.05 TOTHE (1..10))' },
    ],
  },
  text: {
    name: 'Text & String Manipulation',
    items: [
      { title: 'String Literal Vector Concatenation', expr: '"had" "dock" " smells"' },
      { title: 'String Reversal via Index Range Selection', expr: '"stressed" [8..1]' },
      { title: 'Character Occurrence Count', expr: '"The quality of mercy is not strained."="e" INSERT +' },
      { title: 'Caesar Cipher Text Encoding (+3 Shift)', expr: '"attack at dawn" NUMBER +3 LETTER' },
      { title: 'Caesar Cipher Text Decoding (-3 Shift)', expr: '"dwwdfn#dw#gdzq" NUMBER -3 LETTER' },
      { title: 'ASCII Case Conversion (Uppercase Transformation)', expr: '"indoor voice" NUMBER -32 LETTER' },
      { title: 'Palindrome String Validation via Reverse Equality', expr: '"racecar"=("racecar" [7..1]) INSERT AND' },
      { title: 'String Character Length Evaluation', expr: '"cat" LENGTH' },
    ],
  },
  tricks: {
    name: 'Features & Parlour Tricks',
    items: [
      { title: 'Random Discrete Sampling (Two Dice Roll)', expr: '(1..6 PICK) + (1..6 PICK)' },
      { title: 'Variable Storage Assignment', expr: '5: fingers' },
      { title: 'Odd Number Element Filter & Aggregation', expr: '12 34 55 18 67 31 24 ODD INSERT +' },
      { title: 'Modulo Remainder Condition Filter', expr: '1..100 MOD 15=0 INSERT +' },
      { title: 'Greatest Common Divisor (GCD)', expr: '12 18 GCD' },
      { title: 'Least Common Multiple (LCM)', expr: '4 6 10 LCM' },
      { title: 'Vector Mean & Median Calculation', expr: '10 50 20 30 MEAN' },
      { title: 'Combinations Calculation (nCr: 5 choose 2)', expr: '5 COMB 2' },
      { title: 'Permutations Calculation (nPr: 5 perm 2)', expr: '5 PERM 2' },
      { title: 'Primality Check (Is 17 prime?)', expr: '17 PRIME' },
      { title: 'Prime Numbers in Range 1..50', expr: '1..50 PRIMES' },
      { title: 'Vector Dot Product', expr: '(1 2 3) DOT (4 5 6)' },
      { title: 'Vector Euclidean Norm (Magnitude)', expr: '3 4 NORM' },
      { title: 'Hexadecimal to Decimal Conversion', expr: '"FF" FROMHEX' },
    ],
  },
  science: {
    name: 'Scientific & Famous Formulas',
    items: [
      { title: 'Quadratic Formula (Root 1)', desc: '(-b + sqrt(b^2 - 4ac)) / (2a)', expr: '(5 + (((_5 TOTHE 2) - (4 * 1 * 6)) TOTHE .5)) / (2 * 1)' },
      { title: 'Mass-Energy Equivalence (E = mc^2)', expr: '2 * (299792458 TOTHE 2)' },
      { title: 'Area of Circle (A = pi * r^2)', expr: 'PI * (10 TOTHE 2)' },
      { title: 'Volume of Sphere (V = 4/3 * pi * r^3)', expr: '(4 / 3 * PI) * (5 TOTHE 3)' },
      { title: 'Pythagorean Theorem (c = sqrt(a^2 + b^2))', expr: '((3 TOTHE 2) + (4 TOTHE 2)) TOTHE .5' },
      { title: 'Kinetic Energy (E = 0.5 * m * v^2)', expr: '.5 * 20 * (10 TOTHE 2)' },
      { title: 'Joule Electrical Power (P = I^2 * R)', expr: '(5 TOTHE 2) * 12' },
      { title: 'Absolute Temperature Kelvin (T_K = T_C + 273.15)', expr: '0 25 37 100 + 273.15' },
      { title: 'Compound Interest Calculation (A = P(1+r)^t)', expr: '1000 * (1.05 TOTHE 10)' },
      { title: 'Factorial Computation (7!)', expr: '1..7 INSERT *' },
    ],
  },
};

function getSampleList() {
  const list = [];
  let id = 0;
  for (const catKey of Object.keys(SAMPLE_CATEGORIES)) {
    const catObj = SAMPLE_CATEGORIES[catKey];
    for (const item of catObj.items) {
      list.push(Object.assign({}, item, { id: id, category: catKey, categoryName: catObj.name }));
      id++;
    }
  }
  return list;
}

// Module exports for ES / Node / QML / QJSEngine
if (typeof globalThis !== 'undefined') {
  globalThis.AppleError = AppleError;
  globalThis.num = num;
  globalThis.chars = chars;
  globalThis.clump = clump;
  globalThis.tokenize = tokenize;
  globalThis.Machine = Machine;
  globalThis.Parser = Parser;
  globalThis.evaluateExpression = evaluateExpression;
  globalThis.explainExpression = explainExpression;
  globalThis.getSmartErrorTip = getSmartErrorTip;
  globalThis.expandMacros = expandMacros;
  globalThis.SAMPLE_CATEGORIES = SAMPLE_CATEGORIES;
  globalThis.getSampleList = getSampleList;
  globalThis.fmtNum = fmtNum;
  globalThis.render = render;
}

if (typeof exports !== 'undefined') {
  exports.AppleError = AppleError;
  exports.num = num;
  exports.chars = chars;
  exports.clump = clump;
  exports.tokenize = tokenize;
  exports.Machine = Machine;
  exports.Parser = Parser;
  exports.evaluateExpression = evaluateExpression;
  exports.explainExpression = explainExpression;
  exports.getSmartErrorTip = getSmartErrorTip;
  exports.expandMacros = expandMacros;
  exports.SAMPLE_CATEGORIES = SAMPLE_CATEGORIES;
  exports.getSampleList = getSampleList;
  exports.fmtNum = fmtNum;
  exports.render = render;
}
