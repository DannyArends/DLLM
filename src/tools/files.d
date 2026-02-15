/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.conv : to;
import std.path : baseName, buildNormalizedPath;
import std.json : JSONValue;
import std.file : readText, getSize, exists, isDir, dirEntries, SpanMode, write, tempDir;
import std.format : format;
import std.stdio : writefln;
import std.string : replace;
import std.uuid : randomUUID;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Read the contents of a file located at path.")
string readFile(string path) {
  try { return readText(path);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Check if a file or directory exists. Returns 'true' or 'false'.")
string fileExists(string path) {
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

@Tool("Write content to a temporary file located at path. Returns a json containing the file path and file size in bytes.")
string writeFile(string content) {
  try {
    string path = buildNormalizedPath(format("%sagent_%s.txt", tempDir(), randomUUID()));
    path.write(content);
    writefln("=== Wrote to '%s'", path);
    return JSONValue(["path": JSONValue(path), "length": JSONValue(content.length)]).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
