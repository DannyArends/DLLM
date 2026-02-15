/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.path : buildNormalizedPath;
import std.json : JSONValue;
import std.file : readText, write, tempDir;
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

@Tool("Write content to a temporary file located at path. Returns a json containing the file path and content length.")
string writeFile(string content) {
  try {
    string tempPath = buildNormalizedPath(format("%sagent_%s.txt", tempDir(), randomUUID()));
    tempPath = tempPath.replace('\\', '/');
    write(tempPath, content);
    writefln("=== Wrote to '%s'", tempPath);
    return JSONValue(["path": JSONValue(tempPath), "length": JSONValue(content.length)]).toString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
