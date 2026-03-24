/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module sandbox;

import std.file : isDir, write, exists;
import std.format : format;
import std.json : JSONValue;
import std.process : execute;
import std.stdio : writeln;
import std.string : strip, toLower, indexOf;

import files : getTempPath;
import tools : Tool, RegisterTools;
import utils : isSafePath, CWD;

mixin RegisterTools;

@Tool("Execute code located at path in an isolated Docker sandbox, make sure path is an absolute path. Supported languages: 
Python, Javascript, Bash, D, and R.")
string runCode(string language, string path) {
  if (!isSafePath(path, "w")) return(format("Error: path outside allowed directory: '%s'", CWD));
  if (!exists(path)) return(format("Error: file '%s' does not exist", path));
  if (isDir(path)) return(format("Error: path '%s' is a directory, not a file", path));
  try {
    string image;
    string lang_cmd;
    switch (language.toLower()) {
      case "python":     image = "dllm-python";   lang_cmd = "python3 /code"; break;
      case "javascript": image = "node:alpine";   lang_cmd = "node /code";    break;
      case "bash":       image = "alpine";        lang_cmd = "sh /code";      break;
      case "r":          image = "r-base";        lang_cmd = "Rscript /code"; break;
      case "d":          image = "dlanguage/dmd"; lang_cmd = "dmd -run /code"; break;
      default: return(format("Error: unsupported language '%s'", language));
    }

    auto result = execute(["docker", "run", "--rm",
      "--memory", "1024m",
      "--cpus", "2.0",
      "--stop-timeout", "30",
      "--ulimit", "nofile=1024:1024",
      "-v", path ~ ":/code:ro",
      "-v", CWD ~ ":/workspace",
      image,
      "sh", "-c", "cd /workspace && " ~ lang_cmd  // lang_cmd = just the interpreter + /code
    ]);
    return(JSONValue([
      "exit_code": JSONValue(result.status),
      "output":    JSONValue(result.output.strip())
    ]).toString());
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

// Build a Python image which has standard python stuff inside it
// If we need to update, run: docker rmi dllm-python
void ensurePythonImage(string tag = "dllm-python") {
  // Check if image exists
  auto check = execute(["docker", "images", "-q", tag]);
  if (check.output.strip().length > 0) return;

  // Build from inline Dockerfile
  writeln("[docker] Building Python sandbox image...");
  string dockerfile = "FROM python:3.12-slim\n
                       RUN apt-get update && apt-get install -y lame ffmpeg && rm -rf /var/lib/apt/lists/*\n
                       RUN pip install --no-cache-dir numpy scipy pandas matplotlib scikit-learn gtts pydub\n";
  auto tmp = getTempPath("Dockerfile", "dock");  // no extension
  tmp.write(dockerfile);
  auto result = execute(["docker", "build", "-t", tag, "-f", tmp, "."]);
  if (result.status != 0) writeln("[docker] Build failed: ", result.output);
}

