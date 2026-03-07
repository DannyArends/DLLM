/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : join;
import std.conv : to;
import std.path : baseName, buildNormalizedPath;
import std.process : execute;
import std.json : JSONValue;
import std.file : readText, getSize, exists, isDir, dirEntries, SpanMode, write, tempDir;
import std.format : format;
import std.stdio : writefln;
import std.string : replace, strip, toStringz, splitLines;
import std.random : uniform;

import utils;
import agent : agent;
import rag : query, ingest;
import tools : Tool, RegisterTools;

mixin RegisterTools;

immutable string ingestFmt = "File '%s' (%d characters, %d tokens), ingested as %d chunks into RAG";
immutable string memento = "./workspace/MEMENTO.md";

string getTempPath(string extension = "txt") {
  extension = extension.replace(".", "").replace("/", "").replace("\\", "");
  string path = buildNormalizedPath(format("%s/out/agent_%08x.%s", CWD, uniform!uint(), extension));
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
  if (!isSafePath(path)) return "Error: path outside allowed directories";
  int maxLines = to!int(max_results);
  auto result = execute(["grep", "-rn", "-m", to!string(maxLines), pattern, path]);
  return result.output.strip().length > 0 ? result.output.strip() : "No matches found";
}

@Tool("Read lines start_line to end_line (1-based) from a file and return them directly.")
string readFileSection(string path, string start_line, string end_line) {
  if (!isSafePath(path)) return "Error: path outside allowed directories";
  try {
    auto lines = readText(path).splitLines();
    int s = to!int(start_line) - 1;
    int e = to!int(end_line);
    if (s < 0) s = 0;
    if (e > cast(int)lines.length) e = cast(int)lines.length;
    if (s >= e) return("Error: start_line exceeds file length");
    return lines[s..e].join("\n");
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Read / Load the contents of a file located at path into the RAG.")
string readFile(string path) {
  if (!isSafePath(path)) return "Error: path outside allowed directories";
  auto text = readText(path);
  auto nChunk = agent.rag.ingest(text, path);
  return(ingestFmt.format(path, text.length, nChunk[0], nChunk[1]));
}

@Tool("Check if a file or directory exists. Returns 'true' or 'false'.")
string pathExists(string path) {
  if (!isSafePath(path)) return "Error: path outside allowed directories";
  try {
    return exists(path) ? "true" : "false";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Load an image at path into the vision context. The returned [image] marker embeds the image in the tool response.")
string loadImage(string path) {
  if (!isSafePath(path)) return "Error: path outside allowed directories";
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
  if (!isSafePath(path)) return "Error: path outside allowed directories";
  try {
    if (!exists(path)) return "Error: File does not exist";
    if (isDir(path)) return "Error: Path is a directory, not a file";
    return to!string(getSize(path));
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("List files and directories in a path. Returns names, paths, type, and size")
string listDirectory(string path) {
  if (!isSafePath(path)) return "Error: path outside allowed directories";
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

@Tool("Write content to a file in out/, returns the file path.")
string writeFile(string content, string extension = "txt") {
  try {
    string path = getTempPath(extension);
    path.write(content);
    return path;
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Write a Memento to your future self, returns nothing")
string writeMemento(string content) {
  try {
    if (!isSafePath(memento)) return "Error: path outside allowed directories";
    memento.write(content);
    writefln("=== Wrote to '%s'", memento);
    return JSONValue.emptyObject.toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
