/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.file : isDir, write;
import std.format : format;
import std.json : JSONValue;
import std.process : executeShell;
import std.string : strip, toLower;

import files : getTempPath;
import tools : Tool, RegisterTools;
import utils;

mixin RegisterTools;

string dockerFmt = "docker run --rm --memory 1024m --cpus 2.0 --stop-timeout 30 --ulimit nofile=1024:1024 -v %s:/code:ro -v %s:/workspace %s %s 2>&1";

@Tool("Execute code located at path in an isolated Docker sandbox. Supported languages: Python, Javascript, Bash, D, and R.")
string runCode(string language, string path) {
  if (!isSafePath(path)) return "Error: path outside allowed directories";
  if (!exists(path)) return "Error: file does not exist";
  if (isDir(path)) return "Error: path is a directory, not a file";
  try {
    string image;
    string cmd;
    switch (language.toLower()) {
      case "python":     image = "python:3.12-alpine"; cmd = "sh -c \"cd /workspace && python3 /code\"";  break;
      case "javascript": image = "node:alpine";        cmd = "sh -c \"cd /workspace && node /code\"";     break;
      case "bash":       image = "alpine";             cmd = "sh -c \"cd /workspace && sh /code\"";       break;
      case "r":          image = "r-base";             cmd = "sh -c \"cd /workspace && Rscript /code\"";  break;
      case "d":          image = "dlanguage/dmd";      cmd = "sh -c \"cd /workspace && dmd -run /code\""; break;
      default: return(format("Error: unsupported language '%s'", language));
    }

    string docker = format(dockerFmt, path, format("%s\\%s",CWD, "workspace"), image, cmd);
    auto result = executeShell(docker);
    return(JSONValue([
      "exit_code": JSONValue(result.status),
      "output":    JSONValue(result.output.strip())
    ]).toString());
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
