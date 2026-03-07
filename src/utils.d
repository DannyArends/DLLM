/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

public import core.stdc.stdlib : exit;
public import core.stdc.stdio : fflush;
public import std.algorithm : count, endsWith, min, map, sort, sum;
public import std.array : appender, array, replace, join;
public import std.format : format;
public import std.file : exists, readText, remove;
public import std.json : JSONValue;
public import std.math : sqrt;
public import std.range : take, zip;
public import std.stdio : readln, write, writeln, writef, writefln;
public import std.string : strip, fromStringz, toStringz, lastIndexOf;
public import core.time : MonoTime;
public import std.typecons : tuple;

static if(!__traits(compiles, LLAMA_TOKEN_NULL)) {
    llama_token LLAMA_TOKEN_NULL = -1;
}

extern(Windows) uint SetConsoleOutputCP(uint wCodePageID);

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
