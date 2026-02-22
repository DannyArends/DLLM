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
import tools : Tool, RegisterTools;
import vocab : tokenize;

mixin RegisterTools;

string ingestFmt = "File '%s' (%d tokens), ingested into RAG.";

@Tool("Query the RAG index with a question. Returns the most relevant excerpts.")
string queryRAG(string question) {
  auto results = agent.rag.query(question);
  return results.length > 0 ? results.join("\n---\n") : "No relevant results found.";
}

@Tool("Load an image from a file path so it can be analyzed. Returns a placeholder that will be replaced with the image content.")
string loadImage(string path) {
  try {
    if (agent.vision is null) return "Error: vision context not initialized";
      mtmd_bitmap* bmp = mtmd_helper_bitmap_init_from_file(agent.vision, path.toStringz());
      if (bmp is null) return format("Error: failed to load image at '%s'", path);
      agent.pendingBitmaps ~= bmp;
      return format("Image loaded from '%s': <__media__>", path);
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Read / Load into RAG text content from a PDF document at the given path.")
string readPDF(string path) {
  try {
    auto result = executeShell(format("pdftotext '%s' -", path));
    if (result.status != 0) return format("Error: pdftotext failed for '%s'", path);
    auto text = result.output.strip();
    if (text.length == 0) return "Warning: no text extracted, PDF may be scanned/image-based";
    auto tokens = tokenize(agent.rag.vocab, text, false);
    string ingest = ingestFmt.format(path, tokens.length);
    if (tokens.length > tokenize(agent.rag.vocab, ingest, false).length) {
      agent.rag.ingest(text);
      return(ingest);
    }
    return text;
  } catch (Exception e) { return format("Error: %s", e.msg); }
}

@Tool("Read / Load into RAG the contents of a file located at path.")
string readFile(string path) {
  auto text = readText(path);
  auto tokens = tokenize(agent.rag.vocab, text, false);
  string ingest = ingestFmt.format(path, tokens.length);
  if (tokens.length >  tokenize(agent.rag.vocab, ingest, false).length) {
    agent.rag.ingest(text);
    return(ingest);
  }
  return text;
}

@Tool("Check if a file or directory exists. Returns 'true' or 'false'.")
string pathExists(string path) {
  try {
    return exists(path) ? "true" : "false";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Get file size in bytes. Returns error if file doesn't exist or is a directory.")
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
  return(buildNormalizedPath(format("%sagent_%08x.%s", tempDir(), uniform!uint(), extension)));
}

@Tool("Write content to a temporary file located at path. Returns a json containing the file path and file size in bytes.")
string writeFile(string content) {
  try {
    string path = getTempPath();
    path.write(content);
    writefln("=== Wrote to '%s'", path);
    return JSONValue(["path": JSONValue(path), "length": JSONValue(content.length)]).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

