// Generated by BUCKLESCRIPT, PLEASE EDIT WITH CARE
'use strict';

var Sys = require("bs-platform/lib/js/sys.js");
var Bytes = require("bs-platform/lib/js/bytes.js");
var Caml_bytes = require("bs-platform/lib/js/caml_bytes.js");
var Caml_int32 = require("bs-platform/lib/js/caml_int32.js");
var Caml_int64 = require("bs-platform/lib/js/caml_int64.js");
var Caml_string = require("bs-platform/lib/js/caml_string.js");
var Caml_external_polyfill = require("bs-platform/lib/js/caml_external_polyfill.js");

function unsafe_get_nat(s, i) {
  if (Sys.word_size === 32) {
    return Caml_string.caml_string_get32(s, i);
  } else {
    return Caml_int64.get64(s, i)[1] | 0;
  }
}

function unsafe_set_nat(s, i, v) {
  if (Sys.word_size === 32) {
    return Caml_external_polyfill.resolve("string.unsafe_set32")(s, i, v);
  } else {
    return Caml_external_polyfill.resolve("string.unsafe_set64")(s, i, Caml_int64.of_int32(v));
  }
}

function blit_from_bigstring(src, src_off, dst, dst_off, len) {
  for(var i = 0 ,i_finish = len - 1 | 0; i <= i_finish; ++i){
    dst[dst_off + i | 0] = Caml_external_polyfill.resolve("caml_ba_get_1")(src, src_off + i | 0);
  }
  return /* () */0;
}

function rpad(a, size, x) {
  var l = a.length;
  var b = Caml_bytes.caml_create_bytes(size);
  Bytes.blit(a, 0, b, 0, l);
  Bytes.fill(b, l, size - l | 0, x);
  return b;
}

function cpu_to_be32(s, i, v) {
  if (Sys.big_endian) {
    return Caml_external_polyfill.resolve("string.unsafe_set32")(s, i, v);
  } else {
    return Caml_external_polyfill.resolve("string.unsafe_set32")(s, i, Caml_int32.caml_int32_bswap(v));
  }
}

function cpu_to_le32(s, i, v) {
  if (Sys.big_endian) {
    return Caml_external_polyfill.resolve("string.unsafe_set32")(s, i, Caml_int32.caml_int32_bswap(v));
  } else {
    return Caml_external_polyfill.resolve("string.unsafe_set32")(s, i, v);
  }
}

function cpu_to_be64(s, i, v) {
  if (Sys.big_endian) {
    return Caml_external_polyfill.resolve("string.unsafe_set64")(s, i, v);
  } else {
    return Caml_external_polyfill.resolve("string.unsafe_set64")(s, i, Caml_int64.swap(v));
  }
}

function cpu_to_le64(s, i, v) {
  if (Sys.big_endian) {
    return Caml_external_polyfill.resolve("string.unsafe_set64")(s, i, Caml_int64.swap(v));
  } else {
    return Caml_external_polyfill.resolve("string.unsafe_set64")(s, i, v);
  }
}

function be32_to_cpu(s, i) {
  if (Sys.big_endian) {
    return Caml_string.caml_string_get32(s, i);
  } else {
    return Caml_int32.caml_int32_bswap(Caml_string.caml_string_get32(s, i));
  }
}

function le32_to_cpu(s, i) {
  if (Sys.big_endian) {
    return Caml_int32.caml_int32_bswap(Caml_string.caml_string_get32(s, i));
  } else {
    return Caml_string.caml_string_get32(s, i);
  }
}

function be64_to_cpu(s, i) {
  if (Sys.big_endian) {
    return Caml_int64.get64(s, i);
  } else {
    return Caml_int64.swap(Caml_int64.get64(s, i));
  }
}

function le64_to_cpu(s, i) {
  if (Sys.big_endian) {
    return Caml_int64.swap(Caml_int64.get64(s, i));
  } else {
    return Caml_int64.get64(s, i);
  }
}

function benat_to_cpu(s, i) {
  if (Sys.big_endian) {
    return unsafe_get_nat(s, i);
  } else {
    return Caml_int32.caml_int32_bswap(unsafe_get_nat(s, i));
  }
}

function cpu_to_benat(s, i, v) {
  if (Sys.big_endian) {
    return unsafe_set_nat(s, i, v);
  } else {
    return unsafe_set_nat(s, i, Caml_int32.caml_int32_bswap(v));
  }
}

var make = Bytes.make;

var init = Bytes.init;

var empty = Bytes.empty;

var copy = Bytes.copy;

var of_string = Bytes.of_string;

var to_string = Bytes.to_string;

var sub = Bytes.sub;

var sub_string = Bytes.sub_string;

var extend = Bytes.extend;

var fill = Bytes.fill;

var blit = Bytes.blit;

var blit_string = Bytes.blit_string;

var concat = Bytes.concat;

var cat = Bytes.cat;

var iter = Bytes.iter;

var iteri = Bytes.iteri;

var map = Bytes.map;

var mapi = Bytes.mapi;

var trim = Bytes.trim;

var escaped = Bytes.escaped;

var index = Bytes.index;

var index_opt = Bytes.index_opt;

var rindex = Bytes.rindex;

var rindex_opt = Bytes.rindex_opt;

var index_from = Bytes.index_from;

var index_from_opt = Bytes.index_from_opt;

var rindex_from = Bytes.rindex_from;

var rindex_from_opt = Bytes.rindex_from_opt;

var contains = Bytes.contains;

var contains_from = Bytes.contains_from;

var rcontains_from = Bytes.rcontains_from;

var uppercase = Bytes.uppercase;

var lowercase = Bytes.lowercase;

var capitalize = Bytes.capitalize;

var uncapitalize = Bytes.uncapitalize;

var uppercase_ascii = Bytes.uppercase_ascii;

var lowercase_ascii = Bytes.lowercase_ascii;

var capitalize_ascii = Bytes.capitalize_ascii;

var uncapitalize_ascii = Bytes.uncapitalize_ascii;

var compare = Bytes.compare;

var equal = Bytes.equal;

var unsafe_to_string = Bytes.unsafe_to_string;

var unsafe_of_string = Bytes.unsafe_of_string;

exports.make = make;
exports.init = init;
exports.empty = empty;
exports.copy = copy;
exports.of_string = of_string;
exports.to_string = to_string;
exports.sub = sub;
exports.sub_string = sub_string;
exports.extend = extend;
exports.fill = fill;
exports.blit = blit;
exports.blit_string = blit_string;
exports.concat = concat;
exports.cat = cat;
exports.iter = iter;
exports.iteri = iteri;
exports.map = map;
exports.mapi = mapi;
exports.trim = trim;
exports.escaped = escaped;
exports.index = index;
exports.index_opt = index_opt;
exports.rindex = rindex;
exports.rindex_opt = rindex_opt;
exports.index_from = index_from;
exports.index_from_opt = index_from_opt;
exports.rindex_from = rindex_from;
exports.rindex_from_opt = rindex_from_opt;
exports.contains = contains;
exports.contains_from = contains_from;
exports.rcontains_from = rcontains_from;
exports.uppercase = uppercase;
exports.lowercase = lowercase;
exports.capitalize = capitalize;
exports.uncapitalize = uncapitalize;
exports.uppercase_ascii = uppercase_ascii;
exports.lowercase_ascii = lowercase_ascii;
exports.capitalize_ascii = capitalize_ascii;
exports.uncapitalize_ascii = uncapitalize_ascii;
exports.compare = compare;
exports.equal = equal;
exports.unsafe_to_string = unsafe_to_string;
exports.unsafe_of_string = unsafe_of_string;
exports.unsafe_get_nat = unsafe_get_nat;
exports.unsafe_set_nat = unsafe_set_nat;
exports.blit_from_bigstring = blit_from_bigstring;
exports.rpad = rpad;
exports.cpu_to_be32 = cpu_to_be32;
exports.cpu_to_le32 = cpu_to_le32;
exports.cpu_to_be64 = cpu_to_be64;
exports.cpu_to_le64 = cpu_to_le64;
exports.be32_to_cpu = be32_to_cpu;
exports.le32_to_cpu = le32_to_cpu;
exports.be64_to_cpu = be64_to_cpu;
exports.le64_to_cpu = le64_to_cpu;
exports.benat_to_cpu = benat_to_cpu;
exports.cpu_to_benat = cpu_to_benat;
/* No side effect */