/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : join;
import std.conv : to;
import std.path : baseName, buildNormalizedPath;
import std.process : execute, executeShell;
import std.json : JSONValue;
import std.file : readText, getSize, exists, isDir, dirEntries, SpanMode, write, tempDir;
import std.format : format;
import std.stdio : writefln;
import std.string : replace, strip, toStringz, splitLines, indexOf;
import std.random : uniform;

import utils;
import model : tokenize;
import agent : agent;
import rag : query, ingest;
import tools : Tool, RegisterTools;

mixin RegisterTools;

immutable string ingestFmt = "File '%s' (%d characters, %d tokens), ingested as %d chunks into RAG";
immutable string memento = "./templates/MEMENTO.md";

string getTempPath(string prefix, string extension = "txt") {
  prefix = prefix.baseName.replace(".", "").replace("/", "").replace("\\", "");
  extension = extension.baseName.replace(".", "").replace("/", "").replace("\\", "");
  string path = buildNormalizedPath(format("%s/%s_%08x.%s", CWD, prefix, uniform!uint(), extension));
  agent.tmp ~= path;
  return(path);
}

@Tool("Query the RAG index with a question, returns the most relevant excerpts.")
string queryRAG(string question) {
  auto results = agent.rag.query(question);
  return results.length > 0 ? results.join("\n---\n") : "No relevant results found.";
}

@Tool("Search for a pattern in files at path, returns up to max_results matching lines with file and line number")
string grepFiles(string path, string pattern, string max_results) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  int maxLines = to!int(max_results);
  auto result = execute(["grep", "-rn", "-m", to!string(maxLines), pattern, path]);
  return result.output.strip().length > 0 ? result.output.strip() : "No matches found";
}

@Tool("Read lines from a file located at path. Reads all lines from start to end (1-based) and returns them. 
Set end to \"-1\" to read until the end of the file")
string readFile(string path, string start = "1", string end = "-1") {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  try {
    auto lines = readText(path).splitLines();
    int s = to!int(start) - 1;
    int e = to!int(end);
    if (s < 0) s = 0;
    if (e == -1 || e > cast(int)lines.length) e = cast(int)lines.length;
    if (s >= e) return("Error: start after end");
    auto ret = lines[s..e].join("\n");
    auto n = agent.tokenize(ret);
    if(n.length > (0.2 * llama_n_ctx(agent.ctx))) return("Error: tokens exceed KV-window, please use a smaller range or readFileIntoRAG");
    return ret;
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Read / Load the contents of a file located at path into the RAG.")
string readFileIntoRAG(string path) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  auto text = readText(path);
  auto nChunk = agent.rag.ingest(text, path);
  return(ingestFmt.format(path, text.length, nChunk[0], nChunk[1]));
}

@Tool("Check if a file or directory exists. Returns 'true' or 'false'.")
string pathExists(string path) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  try {
    return exists(path) ? "true" : "false";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Load an image at path into the vision context. The returned [image] marker embeds the image in the tool response.")
string loadImage(string path) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  try {
    if (agent.vision is null) return "Error: vision context not initialized";
      mtmd_bitmap* bmp = mtmd_helper_bitmap_init_from_file(agent.vision, path.toStringz());
      if (bmp is null) return format("Error: failed to load image at '%s'", path);
      agent.bitmaps ~= bmp;
      return format("Image loaded from '%s': <__media__>", path);
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Get file size in bytes. Returns an error if the file doesn't exist or is a directory.")
string fileSize(string path) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  try {
    if (!exists(path)) return "Error: File does not exist";
    if (isDir(path)) return "Error: Path is a directory, not a file";
    return to!string(getSize(path));
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("List files and directories in a path. Returns names, paths, type, and size")
string listDirectory(string path) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  try {
    if (!exists(path)) return "Error: Path does not exist";
    if (!isDir(path)) return "Error: Path is not a directory";

    JSONValue[] entries;
    foreach (entry; dirEntries(path, SpanMode.shallow)) {
      JSONValue item = JSONValue.emptyObject;
      item["name"] = JSONValue(baseName(entry.name));
      item["path"] = JSONValue(buildNormalizedPath(entry.name));
      item["type"] = JSONValue(entry.isDir ? "dir" : "file");
      item["size"] = entry.isDir ? JSONValue("-") : JSONValue(entry.size);
      entries ~= item;
    }
    return JSONValue(entries).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Write content to a file in the ./workspace/ folder. Returns a path to the file.")
string writeFile(string content, string extension = "txt") {
  try {
    string path = getTempPath("agent", extension);
    path.write(content);
    return path;
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Replace the line at lineNumber (1-based) in a file at path with replacement.")
string replaceLine(string path, string lineNumber, string replacement) {
  if (!isSafePath(path, "w")) return "Error: path outside allowed directories";
  if (!exists(path)) return "Error: file does not exist";
  try {
    auto lines = readText(path).splitLines();
    int n = to!int(lineNumber) - 1;
    if (n < 0 || n >= cast(int)lines.length) return("Error: line number out of range");
    lines[n] = replacement;
    path.write(lines.join("\n"));
    return("OK");
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Replace the first occurrence of 'search' with 'replacement' in a file at path.")
string replaceInFile(string path, string search, string replacement) {
  if (!isSafePath(path, "w")) return "Error: path outside allowed directories";
  if (!exists(path)) return "Error: file does not exist";
  try {
    string content = readText(path);
    auto idx = content.indexOf(search);
    if (idx < 0) return("Error: search string not found");
    content = content[0..idx] ~ replacement ~ content[idx + search.length..$];
    path.write(content);
    return("OK");
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Write a Memento to your future self, returns nothing")
string writeMemento(string content) {
  try {
    if (!isSafePath(memento, "r")) return "Error: path outside allowed directories";
    memento.write(content);
    writefln("=== Wrote to '%s'", memento);
    return JSONValue.emptyObject.toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Plays a 16-bit PCM WAV file at path on the host speakers.")
string playWAV(string path) {
  if (!isSafePath(path, "r")) return "Error: path outside allowed directories";
  if (!exists(path)) return "Error: file does not exist";
  version(Windows) { auto r = executeShell("powershell -c (New-Object Media.SoundPlayer '" ~ path ~ "').PlaySync()"); }
  version(linux)   { auto r = executeShell("aplay \"" ~ path ~ "\""); }
  return r.status == 0 ? "OK" : "Error: " ~ r.output.strip();
}
