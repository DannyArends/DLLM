/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

public import core.stdc.stdlib : exit;
public import core.stdc.stdio : fflush;
public import std.algorithm : any, count, endsWith, min, map, sort, sum;
public import std.array : appender, array, replace, join;
public import std.digest.md : md5Of, toHexString;
public import std.format : format;
public import std.file : getcwd, exists, readText, remove;
public import std.json : JSONValue;
public import std.math : sqrt;
public import std.numeric : dotProduct;
public import std.path : buildNormalizedPath, absolutePath, isAbsolute, dirSeparator;
public import std.range : take, zip;
public import std.stdio : File, readln, write, writeln, writef, writefln;
public import std.string : strip, fromStringz, toStringz, lastIndexOf, startsWith;
public import core.time : MonoTime;
public import std.typecons : tuple;

static if(!__traits(compiles, LLAMA_TOKEN_NULL)) {
    llama_token LLAMA_TOKEN_NULL = -1;
}

extern(Windows) uint SetConsoleOutputCP(uint wCodePageID);

immutable string CRD;
immutable string CWD;

shared static this() {
  CRD = buildNormalizedPath(getcwd());
  CWD = buildNormalizedPath(CRD ~ "/workspace") ~ dirSeparator;
}

bool isSafePath(string path, string f) {
  string cmp = ((f=="r")? CRD : CWD);
  auto res = buildNormalizedPath(path.absolutePath()).startsWith(cmp);
  if(!res) writeln("====== ! = "~ path);
  return res;
}

// No ouput, only warnings from llama layer
extern(C) void silent_log(ggml_log_level level, const char* text, void* user_data) {
  if(level == GGML_LOG_LEVEL_ERROR)
    writef("%s", fromStringz(text));
}

// Setup console so windows can 'handle emoji'
void setupConsole() {
  version(Windows) { SetConsoleOutputCP(65001); }
  llama_log_set(&silent_log, null);
  mtmd_helper_log_set(&silent_log, null);
}

// Check if not null, if it is exit()
T check(T)(T ptr, string msg) { if (!ptr) { writefln("[ERROR] %s", msg); exit(1); } return ptr; }

// nTokens across all chunks
int nTokens(mtmd_input_chunks* chunks) {
  int total = 0;
  for (size_t i = 0; i < mtmd_input_chunks_size(chunks); i++) {
    total += mtmd_input_chunk_get_n_pos(mtmd_input_chunks_get(chunks, i));
  }
  return total;
}

// Write an array as binary
void writeRAG(T)(ref File f, T[] data) {
  ulong len = data.length; f.rawWrite((&len)[0..1]); f.rawWrite(data);
}

// Read an array from binary
T[] readRAG(T)(ref File f) {
  ulong len; f.rawRead((&len)[0..1]);
  if (len > 100_000_000){ throw new Exception(format("Corrupt RAG: implausible length %d", len)); }
  T[] buf = new T[len]; f.rawRead(buf); return buf;
}
