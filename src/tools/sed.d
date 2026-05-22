/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module sed;

import includes;

import std.algorithm : canFind, filter, map;
import std.array : join, array;
import std.format : format;
import std.file : exists, readText, write;
import std.regex : regex, replaceAll, replaceFirst, matchFirst, Regex, RegexException;
import std.string : split, splitLines;

import utils : isSafePath;
import tools : Tool, RegisterTools;

mixin RegisterTools;

struct EditOp {
  string pattern;
  string cmd;
  string text;
  bool global;
}

EditOp parseOp(string op) {
  auto p = op[1..$].split(op[1]);
  if (p.length < 3) throw new Exception("invalid operation syntax");
  return op[0] == 's' ? EditOp(p[1], "s", p[2], p.length > 3 && p[3].canFind('g')) : EditOp(p[1], p[2], p.length > 3 ? p[3..$].join(op[1]) : "");
}

string applyOp(EditOp op, string line, ref Regex!char re) {
  bool matches = !matchFirst(line, re).empty;
  final switch (op.cmd) {
    case "s": return op.global ? replaceAll(line, re, op.text) : replaceFirst(line, re, op.text);
    case "d": return matches ? null : line;
    case "i": return matches ? op.text ~ "\n" ~ line : line;
    case "a": return matches ? line ~ "\n" ~ op.text : line;
  }
}

@Tool("Edit a file at path using a sed-like operation:
  's/pattern/replacement/' - replace first match per line,
  's/pattern/replacement/g' - replace all matches per line,
  '/pattern/d' - delete lines matching pattern,
  '/pattern/i/text' - insert text before lines matching pattern,
  '/pattern/a/text' - append text after lines matching pattern")
string editFile(string path, string op) {
  if (!isSafePath(path, "w")) return "Error: path outside allowed directory";
  if (!exists(path)) return "Error: file does not exist";
  try {
    auto eop = parseOp(op);
    auto re = regex(eop.pattern);
    auto result = readText(path).splitLines().map!(l => applyOp(eop, l, re)).filter!(l => l !is null).array;
    path.write(result.join("\n"));
    return format("OK (%d lines)", result.length);
  } catch (RegexException e) { return format("Error: invalid regex: %s", e.msg);
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

