/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.file : write, exists, remove;
import std.format : format;
import std.json : JSONValue;
import std.path : buildNormalizedPath;
import std.process : executeShell;
import std.string : strip;

import agent : agent;
import files : getTempPath;
import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Execute code in an isolated Docker sandbox. language can be: python, javascript, bash, r")
string runCode(string language, string code) {
  try {
    string image;
    string cmd;
    switch (language) {
      case "python":     image = "python:3.12-alpine"; cmd = "python3 /code"; break;
      case "javascript": image = "node:alpine";        cmd = "node /code";    break;
      case "bash":       image = "alpine";             cmd = "sh /code";      break;
      case "r":          image = "r-base";             cmd = "Rscript /code"; break;
      default: return format("Error: unsupported language '%s'", language);
    }

    string path = getTempPath(language == "javascript" ? "js" : language);
    path.write(code);

    string docker = format(
      "docker run --rm --memory 1024m --cpus 2.0 " ~
      "--ulimit nofile=1024:1024 -v %s:/code:ro %s %s 2>&1",
      path, image, cmd
    );

    auto result = executeShell(docker);
    return JSONValue([
      "exit_code": JSONValue(result.status),
      "output":    JSONValue(result.output.strip())
    ]).toString();
  } catch (Exception e) { return format("Error: %s", e.msg); }
}
