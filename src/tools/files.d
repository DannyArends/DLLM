/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : join;
import std.conv : to;
import std.path : baseName, buildNormalizedPath;
import std.process : executeShell;
import std.json : JSONValue;
import std.file : readText, getSize, exists, isDir, dirEntries, SpanMode, write, tempDir;
import std.format : format;
import std.stdio : writefln;
import std.string : replace, strip, toStringz;
import std.random : uniform;

import agent : agent;
import rag : query, ingest;
import tools : Tool, RegisterTools;


mixin RegisterTools;

string ingestFmt = "File '%s' (%d characters, %d tokens), ingested as %d chunks into RAG";

@Tool("Query the RAG index with a question, returns the most relevant excerpts.")
string queryRAG(string question) {
  auto results = agent.rag.query(question);
  return results.length > 0 ? results.join("\n---\n") : "No relevant results found.";
}

@Tool("Read / Load into RAG the contents of a file located at path.")
string readFile(string path) {
  auto text = readText(path);
  auto nChunk = agent.rag.ingest(text, path);
  return(ingestFmt.format(path, text.length, nChunk[0], nChunk[1]));
}

@Tool("Check if a file or directory exists. Returns 'true' or 'false'.")
string pathExists(string path) {
  try {
    return exists(path) ? "true" : "false";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Load an image at path into the vision context. The returned [image] marker embeds the image in the tool response.")
string loadImage(string path) {
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
  try {
    if (!exists(path)) return "Error: File does not exist";
    if (isDir(path)) return "Error: Path is a directory, not a file";
    return to!string(getSize(path));
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("List files and directories in a path. Returns names, paths, type, and size")
string listDirectory(string path) {
  try {
    if (!exists(path)) return "Error: Path does not exist";
    if (!isDir(path)) return "Error: Path is not a directory";

    JSONValue[] entries;
    foreach (entry; dirEntries(path, SpanMode.shallow)) {
      JSONValue item = JSONValue.emptyObject;
      item["name"] = JSONValue(baseName(entry.name));
      item["path"] = JSONValue(buildNormalizedPath(entry.name));
      item["type"] = JSONValue(entry.isDir ? "dir" : "file");

      item["size"] = JSONValue("-");
      if (!entry.isDir) {
        try {
          item["size"] = JSONValue(entry.size);
        } catch (Exception e) { item["size"] = JSONValue(0); }
      }
      entries ~= item;
    }

    return JSONValue(entries).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Returns a unique temporary file path with the given extension")
string getTempPath(string extension = "txt"){
  string path = buildNormalizedPath(format("%sagent_%08x.%s", tempDir(), uniform!uint(), extension));
  agent.tmp ~= path;
  return(path);
}

@Tool("Write content to a temporary file located. Returns a json containing the file path and file size in bytes.")
string writeFile(string content) {
  try {
    string path = getTempPath();
    path.write(content);
    writefln("=== Wrote to '%s'", path);
    return JSONValue(["path": JSONValue(path), "length": JSONValue(content.length)]).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Write content to the memory file. Returns a json containing the file path and file size in bytes.")
string writeMemory(string content) {
  try {
    string path = "data/memory.txt";
    path.write(content);
    writefln("=== Wrote to '%s'", path);
    return JSONValue(["path": JSONValue(path), "length": JSONValue(content.length)]).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
