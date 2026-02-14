import std.stdio : writefln, writef;
import std.string : fromStringz;

import includes;

extern(Windows) uint SetConsoleOutputCP(uint wCodePageID);

// No ouput, only warnings from llama layer
extern(C) void silent_log(ggml_log_level level, const char* text, void* user_data) {
  if(level == GGML_LOG_LEVEL_ERROR) writefln("ERROR: %s", fromStringz(text));
}

// Setup console so windows can 'handle emoji'
void setupConsole(){
  version(Windows) { SetConsoleOutputCP(65001); }
  llama_log_set(&silent_log, null);
}
