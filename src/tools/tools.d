/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.array : appender;
import std.json : JSONValue, parseJSON;
import std.regex : regex, matchAll;
import std.stdio : writefln;
import std.string : lastIndexOf;

import files : readFile;

// Tool definition
struct ToolDef {
  string name;
  string description;
  string[string] parameters;
}

// Tool Call definition
struct ToolCall {
  string name;
  JSONValue arguments;
}

// Tool registry
immutable ToolDef[] ALL_TOOLS;

shared static this() {
  ALL_TOOLS = [
    ToolDef("readFile", "Read the contents of a file.", ["path": "string"])
  ];
}

// Parse tool call from model output
ToolCall[] parseToolCalls(string response) {
  auto thinkEnd = response.lastIndexOf("</think>\n");
  if (thinkEnd >= 0) response = response[thinkEnd + "</think>\n".length .. $];

  ToolCall[] calls;
  auto pattern = regex(r"<tool_call>\s*(\{.*?\})\s*</tool_call>", "gs");
  foreach(match; matchAll(response, pattern)) {
    try {
      JSONValue json = parseJSON(match[1]);
      if ("name" in json && "arguments" in json) { calls ~= ToolCall(json["name"].str, json["arguments"]); }
    } catch (Exception e) {
      writefln("Failed to parse tool call: %s", e.msg);
    }
  }
  return calls;
}

// Execute tool by name with JSON arguments
string executeTool(string toolName, JSONValue args) {
  try {
    switch(toolName) {
      case "readFile":
        if ("path" in args) return readFile(args["path"].str);
        return "Error: missing path parameter";
      default:
        return "Error: unknown tool '" ~ toolName ~ "'";
    }
  } catch (Exception e) { return "Error executing tool: " ~ e.msg; }
}

// Execute all tool calls and format responses
string executeToolCalls(ToolCall[] calls) {
  auto result = appender!string;
  foreach(call; calls) {
    string toolResult = executeTool(call.name, call.arguments);
    JSONValue response = JSONValue(["tool": JSONValue(call.name), "result": JSONValue(toolResult)]);
    result ~= "<tool_response>\n";
    result ~= response.toPrettyString();
    result ~= "\n</tool_response>\n";
  }
  return result.data;
}

// Generate tools JSON for system prompt
string toolsToJSON() {
  auto result = appender!string;

  result ~= "[";
  foreach(i, tool; ALL_TOOLS) {
    if (i > 0) result ~= ",";
    JSONValue toolJson = JSONValue([
          "name": JSONValue(tool.name),
          "description": JSONValue(tool.description),
          "parameters": JSONValue([
              "type": JSONValue("object"),
              "properties": JSONValue(tool.parameters)
          ])
      ]);
    result ~= toolJson.toPrettyString();
  }
  result ~= "]";
  return result.data;
}
